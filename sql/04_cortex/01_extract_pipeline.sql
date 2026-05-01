/*==============================================================================
EXTRACTION PIPELINE - Expense Rodeo
Defines the AI_EXTRACT + flattening logic and a stored procedure that batches
it across every file in @RECEIPTS_STAGE.

This procedure is the "refresh" button for the demo: run it after you have
PUT new receipts to the stage to replace the synthetic seed rows with live
AI_EXTRACT output.

Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR;
USE WAREHOUSE SFE_RECEIPT_EXTRACTOR_WH;

CREATE OR REPLACE PROCEDURE SP_RECEIPT_EXTRACT_ALL()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: Batch AI_EXTRACT across every file in RECEIPTS_STAGE (Expires: 2026-05-30)'
AS
$$
BEGIN
    -- 1. Make sure the directory table reflects files PUT into the stage.
    ALTER STAGE RECEIPTS_STAGE REFRESH;

    -- 2. Call AI_EXTRACT once per file. Keeps raw VARIANT for audit.
    CREATE OR REPLACE TEMPORARY TABLE _RAW_EXTRACT AS
    SELECT
        RELATIVE_PATH AS FILE_PATH,
        SIZE          AS FILE_SIZE,
        LAST_MODIFIED,
        AI_EXTRACT(
            file => TO_FILE('@RECEIPTS_STAGE', RELATIVE_PATH),
            responseFormat => {
                'vendor':         'Merchant or vendor name exactly as it appears',
                'receipt_date':   'Date on the receipt in YYYY-MM-DD',
                'total_amount':   'Grand total as a number, no currency symbol',
                'currency':       'ISO 4217 currency code (USD, EUR, GBP, ...)',
                'payment_method': 'Payment method -- card last-4 or cash or other',
                'category':       'One of: meals, travel, lodging, supplies, mileage, other',
                'line_items':     'Array of objects with description, qty, unit_price, amount'
            }
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
    MERGE INTO RECEIPTS tgt
    USING (
        SELECT
            r.FILE_PATH,
            r.EXTRACTION:response:vendor::STRING                               AS VENDOR,
            TRY_TO_DATE(r.EXTRACTION:response:receipt_date::STRING)            AS RECEIPT_DATE,
            TRY_TO_NUMBER(
                REGEXP_REPLACE(r.EXTRACTION:response:total_amount::STRING,
                               '[^0-9\\.-]', ''),
                18, 2)                                                         AS TOTAL_AMOUNT,
            COALESCE(r.EXTRACTION:response:currency::STRING, 'USD')            AS CURRENCY,
            r.EXTRACTION:response:payment_method::STRING                       AS PAYMENT_METHOD,
            LOWER(r.EXTRACTION:response:category::STRING)                      AS CATEGORY,
            r.EXTRACTION:response:line_items                                   AS LINE_ITEMS
        FROM _RAW_EXTRACT r
        WHERE r.EXTRACTION:response IS NOT NULL
    ) src
    ON tgt.FILE_PATH = src.FILE_PATH
    WHEN MATCHED THEN UPDATE SET
        VENDOR = src.VENDOR, RECEIPT_DATE = src.RECEIPT_DATE,
        TOTAL_AMOUNT = src.TOTAL_AMOUNT, CURRENCY = src.CURRENCY,
        PAYMENT_METHOD = src.PAYMENT_METHOD, CATEGORY = src.CATEGORY,
        LINE_ITEMS = src.LINE_ITEMS, EXTRACTED_AT = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT
        (FILE_PATH, VENDOR, RECEIPT_DATE, TOTAL_AMOUNT, CURRENCY,
         PAYMENT_METHOD, CATEGORY, LINE_ITEMS)
        VALUES (src.FILE_PATH, src.VENDOR, src.RECEIPT_DATE, src.TOTAL_AMOUNT,
                src.CURRENCY, src.PAYMENT_METHOD, src.CATEGORY, src.LINE_ITEMS);

    RETURN 'Extraction complete';
END;
$$;

-- Analytical views used by the Streamlit + semantic view.
CREATE OR REPLACE VIEW V_SPEND_BY_CATEGORY
COMMENT = 'DEMO: Total spend per category (Expires: 2026-05-30)'
AS
SELECT
    CATEGORY,
    COUNT(*)          AS RECEIPT_COUNT,
    SUM(TOTAL_AMOUNT) AS TOTAL_SPEND,
    AVG(TOTAL_AMOUNT) AS AVG_SPEND
FROM RECEIPTS
WHERE CATEGORY IS NOT NULL
GROUP BY CATEGORY;

CREATE OR REPLACE VIEW V_SPEND_BY_VENDOR
COMMENT = 'DEMO: Total spend per vendor (Expires: 2026-05-30)'
AS
SELECT
    VENDOR,
    COUNT(*)          AS RECEIPT_COUNT,
    SUM(TOTAL_AMOUNT) AS TOTAL_SPEND,
    MIN(RECEIPT_DATE) AS FIRST_RECEIPT,
    MAX(RECEIPT_DATE) AS LAST_RECEIPT
FROM RECEIPTS
WHERE VENDOR IS NOT NULL
GROUP BY VENDOR;

SELECT 'Extraction pipeline + views ready' AS status;
