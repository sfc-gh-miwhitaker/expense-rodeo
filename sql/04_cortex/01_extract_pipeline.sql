/*==============================================================================
EXTRACTION PIPELINE - Expense Rodeo
Defines the AI_EXTRACT + flattening logic and a stored procedure that batches
it across every file in @RECEIPTS_STAGE.

Uses current (2026-Q2) AI_EXTRACT best practices:
  * Combined JSON schema: entities + table extraction in a single call
  * scores => TRUE for per-field confidence (GA)
  * Proper table schema with column_ordering for line items
  * config => {scale_factor} exposed as a procedure argument for dense receipts

Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.EXPENSE_RODEO;
USE WAREHOUSE SFE_EXPENSE_RODEO_WH;

CREATE OR REPLACE PROCEDURE SP_RECEIPT_EXTRACT_ALL(SCALE_FACTOR FLOAT DEFAULT 1.0)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: Batch AI_EXTRACT across every file in RECEIPTS_STAGE (Expires: 2026-05-30)'
AS
$$
BEGIN
    -- 1. Make sure the directory table reflects files PUT into the stage.
    ALTER STAGE RECEIPTS_STAGE REFRESH;

    -- 2. Call AI_EXTRACT once per file with combined JSON schema, confidence
    --    scores, and configurable scale factor for dense/small-text receipts.
    CREATE OR REPLACE TEMPORARY TABLE _RAW_EXTRACT AS
    SELECT
        RELATIVE_PATH AS FILE_PATH,
        SIZE          AS FILE_SIZE,
        LAST_MODIFIED,
        AI_EXTRACT(
            file => TO_FILE('@RECEIPTS_STAGE', RELATIVE_PATH),
            responseFormat => {
                'schema': {
                    'type': 'object',
                    'properties': {
                        'vendor': {
                            'description': 'Merchant or vendor name exactly as it appears on the receipt',
                            'type': 'string'
                        },
                        'receipt_date': {
                            'description': 'Date on the receipt in YYYY-MM-DD',
                            'type': 'string'
                        },
                        'total_amount': {
                            'description': 'Grand total as a number, no currency symbol',
                            'type': 'string'
                        },
                        'currency': {
                            'description': 'ISO 4217 currency code (USD, EUR, GBP, ...)',
                            'type': 'string'
                        },
                        'payment_method': {
                            'description': 'Payment method -- card last-4 or cash or other',
                            'type': 'string'
                        },
                        'category': {
                            'description': 'One of: meals, travel, lodging, supplies, mileage, other',
                            'type': 'string'
                        },
                        'line_items': {
                            'description': 'Line items / purchased items table on the receipt',
                            'type': 'object',
                            'column_ordering': ['description', 'quantity', 'unit_price', 'amount'],
                            'properties': {
                                'description': {'description': 'Item description', 'type': 'array'},
                                'quantity':    {'description': 'Quantity',         'type': 'array'},
                                'unit_price':  {'description': 'Unit price',       'type': 'array'},
                                'amount':      {'description': 'Line total',       'type': 'array'}
                            }
                        }
                    }
                }
            },
            scores => TRUE,
            config => {'scale_factor': :SCALE_FACTOR}
        ) AS EXTRACTION
    FROM DIRECTORY(@RECEIPTS_STAGE)
    WHERE RELATIVE_PATH ILIKE ANY ('%.pdf', '%.jpg', '%.jpeg', '%.png', '%.tif', '%.tiff');

    -- 3. Replace RECEIPTS_RAW with latest extraction.
    DELETE FROM RECEIPTS_RAW
    WHERE FILE_PATH IN (SELECT FILE_PATH FROM _RAW_EXTRACT);

    INSERT INTO RECEIPTS_RAW (FILE_PATH, FILE_SIZE, LAST_MODIFIED, EXTRACTION)
    SELECT FILE_PATH, FILE_SIZE, LAST_MODIFIED, EXTRACTION
    FROM _RAW_EXTRACT;

    -- 4. Flatten into the typed RECEIPTS table.
    --    line_items arrives as column-oriented arrays -- transpose to an array
    --    of objects (one object per line item) using OBJECT_CONSTRUCT inside
    --    ARRAY_AGG over a zipped set.
    MERGE INTO RECEIPTS tgt
    USING (
        WITH raw AS (
            SELECT
                r.FILE_PATH,
                r.EXTRACTION:response                   AS resp,
                r.EXTRACTION:scoring:scores             AS scores
            FROM _RAW_EXTRACT r
            WHERE r.EXTRACTION:response IS NOT NULL
        ),
        line_items AS (
            SELECT
                FILE_PATH,
                ARRAY_AGG(OBJECT_CONSTRUCT(
                    'description', desc_arr.VALUE::STRING,
                    'quantity',    TRY_TO_NUMBER(qty_arr.VALUE::STRING),
                    'unit_price',  TRY_TO_NUMBER(
                                      REGEXP_REPLACE(up_arr.VALUE::STRING, '[^0-9\\.-]', ''),
                                      18, 2),
                    'amount',      TRY_TO_NUMBER(
                                      REGEXP_REPLACE(amt_arr.VALUE::STRING, '[^0-9\\.-]', ''),
                                      18, 2)
                )) WITHIN GROUP (ORDER BY desc_arr.INDEX) AS ITEMS
            FROM raw,
                 LATERAL FLATTEN(input => resp:line_items:description) desc_arr,
                 LATERAL FLATTEN(input => resp:line_items:quantity)    qty_arr,
                 LATERAL FLATTEN(input => resp:line_items:unit_price)  up_arr,
                 LATERAL FLATTEN(input => resp:line_items:amount)      amt_arr
            WHERE desc_arr.INDEX = qty_arr.INDEX
              AND desc_arr.INDEX = up_arr.INDEX
              AND desc_arr.INDEX = amt_arr.INDEX
            GROUP BY FILE_PATH
        )
        SELECT
            raw.FILE_PATH,
            raw.resp:vendor::STRING                                              AS VENDOR,
            TRY_TO_DATE(raw.resp:receipt_date::STRING)                           AS RECEIPT_DATE,
            TRY_TO_NUMBER(
                REGEXP_REPLACE(raw.resp:total_amount::STRING, '[^0-9\\.-]', ''),
                18, 2)                                                           AS TOTAL_AMOUNT,
            COALESCE(raw.resp:currency::STRING, 'USD')                           AS CURRENCY,
            raw.resp:payment_method::STRING                                      AS PAYMENT_METHOD,
            LOWER(raw.resp:category::STRING)                                     AS CATEGORY,
            COALESCE(li.ITEMS, raw.resp:line_items)                              AS LINE_ITEMS,
            /* Average per-field confidence (0..1). Table fields return one
               aggregate score per table -- that's included in the average. */
            (COALESCE(raw.scores:vendor:score::FLOAT,         0)
           + COALESCE(raw.scores:receipt_date:score::FLOAT,   0)
           + COALESCE(raw.scores:total_amount:score::FLOAT,   0)
           + COALESCE(raw.scores:currency:score::FLOAT,       0)
           + COALESCE(raw.scores:payment_method:score::FLOAT, 0)
           + COALESCE(raw.scores:category:score::FLOAT,       0)
           + COALESCE(raw.scores:line_items:score::FLOAT,     0)) / 7           AS AVG_CONFIDENCE
        FROM raw
        LEFT JOIN line_items li USING (FILE_PATH)
    ) src
    ON tgt.FILE_PATH = src.FILE_PATH
    WHEN MATCHED THEN UPDATE SET
        VENDOR = src.VENDOR, RECEIPT_DATE = src.RECEIPT_DATE,
        TOTAL_AMOUNT = src.TOTAL_AMOUNT, CURRENCY = src.CURRENCY,
        PAYMENT_METHOD = src.PAYMENT_METHOD, CATEGORY = src.CATEGORY,
        LINE_ITEMS = src.LINE_ITEMS, AVG_CONFIDENCE = src.AVG_CONFIDENCE,
        EXTRACTED_AT = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT
        (FILE_PATH, VENDOR, RECEIPT_DATE, TOTAL_AMOUNT, CURRENCY,
         PAYMENT_METHOD, CATEGORY, LINE_ITEMS, AVG_CONFIDENCE)
        VALUES (src.FILE_PATH, src.VENDOR, src.RECEIPT_DATE, src.TOTAL_AMOUNT,
                src.CURRENCY, src.PAYMENT_METHOD, src.CATEGORY,
                src.LINE_ITEMS, src.AVG_CONFIDENCE);

    RETURN 'Extraction complete';
END;
$$;

-- Analytical views used by the Streamlit + semantic view.
CREATE OR REPLACE VIEW V_SPEND_BY_CATEGORY
COMMENT = 'DEMO: Total spend per category (Expires: 2026-05-30)'
AS
SELECT
    CATEGORY,
    COUNT(*)            AS RECEIPT_COUNT,
    SUM(TOTAL_AMOUNT)   AS TOTAL_SPEND,
    AVG(TOTAL_AMOUNT)   AS AVG_SPEND,
    AVG(AVG_CONFIDENCE) AS AVG_CONFIDENCE
FROM RECEIPTS
WHERE CATEGORY IS NOT NULL
GROUP BY CATEGORY;

CREATE OR REPLACE VIEW V_SPEND_BY_VENDOR
COMMENT = 'DEMO: Total spend per vendor (Expires: 2026-05-30)'
AS
SELECT
    VENDOR,
    COUNT(*)            AS RECEIPT_COUNT,
    SUM(TOTAL_AMOUNT)   AS TOTAL_SPEND,
    AVG(AVG_CONFIDENCE) AS AVG_CONFIDENCE,
    MIN(RECEIPT_DATE)   AS FIRST_RECEIPT,
    MAX(RECEIPT_DATE)   AS LAST_RECEIPT
FROM RECEIPTS
WHERE VENDOR IS NOT NULL
GROUP BY VENDOR;

-- Low-confidence review queue: surface any extraction below 0.80 so a human
-- can spot-check. Useful demo talk-track for AP / finance personas.
CREATE OR REPLACE VIEW V_LOW_CONFIDENCE_RECEIPTS
COMMENT = 'DEMO: Receipts with average AI_EXTRACT confidence < 0.80 (Expires: 2026-05-30)'
AS
SELECT FILE_PATH, VENDOR, RECEIPT_DATE, TOTAL_AMOUNT, CURRENCY,
       CATEGORY, AVG_CONFIDENCE
FROM RECEIPTS
WHERE AVG_CONFIDENCE < 0.80
ORDER BY AVG_CONFIDENCE;
