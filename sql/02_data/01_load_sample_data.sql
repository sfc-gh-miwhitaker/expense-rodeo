/*==============================================================================
SAMPLE DATA - Expense Rodeo
Seeds synthetic receipts into RECEIPTS + RECEIPTS_RAW so the demo is runnable
even before any real files land in @RECEIPTS_STAGE.

If you have real receipt files, PUT them into @RECEIPTS_STAGE (see bottom of
this file) and then CALL SP_RECEIPT_EXTRACT_ALL() from 04_cortex/01_extract_pipeline.sql
to replace these rows with live AI_EXTRACT output.

Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR;
USE WAREHOUSE SFE_RECEIPT_EXTRACTOR_WH;

-- Reset for idempotent re-runs of the demo.
TRUNCATE TABLE IF EXISTS RECEIPTS;
TRUNCATE TABLE IF EXISTS RECEIPTS_RAW;

-- Synthetic receipts covering the supported categories and file types.
INSERT INTO RECEIPTS (FILE_PATH, VENDOR, RECEIPT_DATE, TOTAL_AMOUNT, CURRENCY,
                      PAYMENT_METHOD, CATEGORY, LINE_ITEMS)
SELECT
    column1, column2, column3::DATE, column4, column5, column6, column7,
    PARSE_JSON(column8)
FROM (VALUES
    ('starbucks_2026_04_12.jpg', 'Starbucks',            '2026-04-12',   8.47, 'USD', 'Visa ****4242',  'meals',
     '[{"description":"Grande Latte","qty":1,"unit_price":5.95,"amount":5.95},{"description":"Blueberry Scone","qty":1,"unit_price":2.52,"amount":2.52}]'),
    ('united_2026_04_05.pdf',     'United Airlines',      '2026-04-05', 412.30, 'USD', 'Amex ****1001',  'travel',
     '[{"description":"SFO -> ORD economy","qty":1,"unit_price":412.30,"amount":412.30}]'),
    ('marriott_2026_04_06.pdf',   'Marriott Bonvoy',      '2026-04-06', 289.55, 'USD', 'Amex ****1001',  'lodging',
     '[{"description":"Room rate","qty":2,"unit_price":129.00,"amount":258.00},{"description":"Resort fee","qty":2,"unit_price":15.77,"amount":31.55}]'),
    ('staples_2026_04_08.png',    'Staples',              '2026-04-08',  36.12, 'USD', 'Visa ****4242',  'supplies',
     '[{"description":"Notebook, 3-pack","qty":1,"unit_price":12.00,"amount":12.00},{"description":"Black gel pens","qty":2,"unit_price":11.00,"amount":22.00}]'),
    ('uber_2026_04_11.pdf',       'Uber',                 '2026-04-11',  24.80, 'USD', 'Amex ****1001',  'travel',
     '[{"description":"UberX airport -> hotel","qty":1,"unit_price":24.80,"amount":24.80}]'),
    ('chipotle_2026_04_09.jpg',   'Chipotle',             '2026-04-09',  14.95, 'USD', 'Visa ****4242',  'meals',
     '[{"description":"Chicken bowl","qty":1,"unit_price":11.95,"amount":11.95},{"description":"Bottled drink","qty":1,"unit_price":3.00,"amount":3.00}]'),
    ('shell_2026_04_10.png',      'Shell',                '2026-04-10',  52.18, 'USD', 'Fleet Card',     'mileage',
     '[{"description":"Regular unleaded, 11.2 gal","qty":11.2,"unit_price":4.66,"amount":52.18}]'),
    ('hilton_2026_04_15.pdf',     'Hilton Hotels',        '2026-04-15', 317.45, 'USD', 'Amex ****1001',  'lodging',
     '[{"description":"Room rate","qty":2,"unit_price":142.00,"amount":284.00},{"description":"Parking","qty":2,"unit_price":16.72,"amount":33.45}]'),
    ('delta_2026_04_18.pdf',      'Delta Air Lines',      '2026-04-18', 498.60, 'USD', 'Amex ****1001',  'travel',
     '[{"description":"SFO -> JFK economy","qty":1,"unit_price":498.60,"amount":498.60}]'),
    ('panera_2026_04_19.jpg',     'Panera Bread',         '2026-04-19',  18.42, 'USD', 'Visa ****4242',  'meals',
     '[{"description":"Mediterranean bowl","qty":1,"unit_price":12.99,"amount":12.99},{"description":"Iced tea","qty":1,"unit_price":3.50,"amount":3.50},{"description":"Cookie","qty":1,"unit_price":1.93,"amount":1.93}]'),
    ('amazon_2026_04_20.pdf',     'Amazon Business',      '2026-04-20',  73.84, 'USD', 'Visa ****4242',  'supplies',
     '[{"description":"USB-C hub","qty":1,"unit_price":42.99,"amount":42.99},{"description":"HDMI cable 6ft","qty":2,"unit_price":15.42,"amount":30.85}]'),
    ('lyft_2026_04_21.pdf',       'Lyft',                 '2026-04-21',  18.10, 'USD', 'Amex ****1001',  'travel',
     '[{"description":"Lyft Standard","qty":1,"unit_price":18.10,"amount":18.10}]')
);

-- Mirror into RECEIPTS_RAW so the Streamlit can show the "raw response" panel.
INSERT INTO RECEIPTS_RAW (FILE_PATH, FILE_SIZE, LAST_MODIFIED, EXTRACTION)
SELECT
    FILE_PATH,
    ABS(HASH(FILE_PATH)) % 250000 + 50000    AS FILE_SIZE,
    DATEADD('hour', -(ABS(HASH(FILE_PATH)) % 72), CURRENT_TIMESTAMP()) AS LAST_MODIFIED,
    OBJECT_CONSTRUCT(
        'response', OBJECT_CONSTRUCT(
            'vendor',         VENDOR,
            'receipt_date',   RECEIPT_DATE::VARCHAR,
            'total_amount',   TOTAL_AMOUNT::VARCHAR,
            'currency',       CURRENCY,
            'payment_method', PAYMENT_METHOD,
            'category',       CATEGORY,
            'line_items',     LINE_ITEMS
        )
    )::VARIANT AS EXTRACTION
FROM RECEIPTS;

----------------------------------------------------------------------
-- To use with real files:
--   1. PUT file://./sample_data/*.pdf @RECEIPTS_STAGE AUTO_COMPRESS=FALSE;
--   2. PUT file://./sample_data/*.jpg @RECEIPTS_STAGE AUTO_COMPRESS=FALSE;
--   3. ALTER STAGE RECEIPTS_STAGE REFRESH;
--   4. CALL SP_RECEIPT_EXTRACT_ALL();
----------------------------------------------------------------------

SELECT COUNT(*) AS sample_rows_loaded FROM RECEIPTS;
