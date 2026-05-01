/*==============================================================================
DEPLOY ALL - Expense Rodeo
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
INSTRUCTIONS:
  1. Open this file in Snowsight, click Run All.
  2. (Optional) To process real receipts, PUT them into @RECEIPTS_STAGE then
     CALL SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR.SP_RECEIPT_EXTRACT_ALL();
  3. Open the RECEIPT_EXPLORER Streamlit under Projects > Streamlit.

NOTE: To deploy the Streamlit UI, upload streamlit/streamlit_app.py to
@RECEIPT_EXPLORER_STAGE before running the CREATE STREAMLIT step (see
sql/05_streamlit/01_create_dashboard.sql).
==============================================================================*/

-- 1. Expiration check (informational only)
SELECT
    '2026-05-30'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) < 0
            THEN 'EXPIRED - Code may use outdated syntax.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) <= 7
            THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) || ' days remaining'
    END AS demo_status;

-- 2. Grants for Cortex AI
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SYSADMIN;

-- 3. Provision schema, warehouse, stage, and tables (inline -- no Git repo yet)
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for SE Community demo projects';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR
  COMMENT = 'DEMO: Receipt Extractor project (Expires: 2026-05-30)';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared schema for Cortex Analyst semantic views';

CREATE WAREHOUSE IF NOT EXISTS SFE_RECEIPT_EXTRACTOR_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'DEMO: Receipt Extractor compute (Expires: 2026-05-30)';

USE WAREHOUSE SFE_RECEIPT_EXTRACTOR_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR;

CREATE STAGE IF NOT EXISTS RECEIPTS_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'DEMO: Landing zone for employee expense receipts (Expires: 2026-05-30)';

CREATE TABLE IF NOT EXISTS RECEIPTS_RAW (
    FILE_PATH      VARCHAR NOT NULL,
    FILE_SIZE      NUMBER,
    LAST_MODIFIED  TIMESTAMP_TZ,
    EXTRACTION     VARIANT,
    EXTRACTED_AT   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Raw AI_EXTRACT response per receipt file (Expires: 2026-05-30)';

CREATE TABLE IF NOT EXISTS RECEIPTS (
    FILE_PATH       VARCHAR PRIMARY KEY,
    VENDOR          VARCHAR,
    RECEIPT_DATE    DATE,
    TOTAL_AMOUNT    NUMBER(12,2),
    CURRENCY        VARCHAR(3),
    PAYMENT_METHOD  VARCHAR,
    CATEGORY        VARCHAR,
    LINE_ITEMS      VARIANT,
    EXTRACTED_AT    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Typed receipt fact table (Expires: 2026-05-30)';

-- 02_data/01_load_sample_data.sql (seed rows; see that file for full list)
TRUNCATE TABLE IF EXISTS RECEIPTS;
TRUNCATE TABLE IF EXISTS RECEIPTS_RAW;

INSERT INTO RECEIPTS (FILE_PATH, VENDOR, RECEIPT_DATE, TOTAL_AMOUNT, CURRENCY,
                      PAYMENT_METHOD, CATEGORY, LINE_ITEMS)
SELECT column1, column2, column3::DATE, column4, column5, column6, column7, PARSE_JSON(column8)
FROM (VALUES
    ('starbucks_2026_04_12.jpg', 'Starbucks',       '2026-04-12',   8.47, 'USD', 'Visa ****4242', 'meals',
     '[{"description":"Grande Latte","qty":1,"unit_price":5.95,"amount":5.95},{"description":"Blueberry Scone","qty":1,"unit_price":2.52,"amount":2.52}]'),
    ('united_2026_04_05.pdf',    'United Airlines', '2026-04-05', 412.30, 'USD', 'Amex ****1001', 'travel',
     '[{"description":"SFO -> ORD economy","qty":1,"unit_price":412.30,"amount":412.30}]'),
    ('marriott_2026_04_06.pdf',  'Marriott Bonvoy', '2026-04-06', 289.55, 'USD', 'Amex ****1001', 'lodging',
     '[{"description":"Room rate","qty":2,"unit_price":129.00,"amount":258.00},{"description":"Resort fee","qty":2,"unit_price":15.77,"amount":31.55}]'),
    ('staples_2026_04_08.png',   'Staples',         '2026-04-08',  36.12, 'USD', 'Visa ****4242', 'supplies',
     '[{"description":"Notebook, 3-pack","qty":1,"unit_price":12.00,"amount":12.00},{"description":"Black gel pens","qty":2,"unit_price":11.00,"amount":22.00}]'),
    ('uber_2026_04_11.pdf',      'Uber',            '2026-04-11',  24.80, 'USD', 'Amex ****1001', 'travel',
     '[{"description":"UberX airport -> hotel","qty":1,"unit_price":24.80,"amount":24.80}]'),
    ('chipotle_2026_04_09.jpg',  'Chipotle',        '2026-04-09',  14.95, 'USD', 'Visa ****4242', 'meals',
     '[{"description":"Chicken bowl","qty":1,"unit_price":11.95,"amount":11.95},{"description":"Bottled drink","qty":1,"unit_price":3.00,"amount":3.00}]'),
    ('shell_2026_04_10.png',     'Shell',           '2026-04-10',  52.18, 'USD', 'Fleet Card',    'mileage',
     '[{"description":"Regular unleaded, 11.2 gal","qty":11.2,"unit_price":4.66,"amount":52.18}]'),
    ('hilton_2026_04_15.pdf',    'Hilton Hotels',   '2026-04-15', 317.45, 'USD', 'Amex ****1001', 'lodging',
     '[{"description":"Room rate","qty":2,"unit_price":142.00,"amount":284.00},{"description":"Parking","qty":2,"unit_price":16.72,"amount":33.45}]'),
    ('delta_2026_04_18.pdf',     'Delta Air Lines', '2026-04-18', 498.60, 'USD', 'Amex ****1001', 'travel',
     '[{"description":"SFO -> JFK economy","qty":1,"unit_price":498.60,"amount":498.60}]'),
    ('panera_2026_04_19.jpg',    'Panera Bread',    '2026-04-19',  18.42, 'USD', 'Visa ****4242', 'meals',
     '[{"description":"Mediterranean bowl","qty":1,"unit_price":12.99,"amount":12.99},{"description":"Iced tea","qty":1,"unit_price":3.50,"amount":3.50},{"description":"Cookie","qty":1,"unit_price":1.93,"amount":1.93}]'),
    ('amazon_2026_04_20.pdf',    'Amazon Business', '2026-04-20',  73.84, 'USD', 'Visa ****4242', 'supplies',
     '[{"description":"USB-C hub","qty":1,"unit_price":42.99,"amount":42.99},{"description":"HDMI cable 6ft","qty":2,"unit_price":15.42,"amount":30.85}]'),
    ('lyft_2026_04_21.pdf',      'Lyft',            '2026-04-21',  18.10, 'USD', 'Amex ****1001', 'travel',
     '[{"description":"Lyft Standard","qty":1,"unit_price":18.10,"amount":18.10}]')
);

INSERT INTO RECEIPTS_RAW (FILE_PATH, FILE_SIZE, LAST_MODIFIED, EXTRACTION)
SELECT
    FILE_PATH,
    ABS(HASH(FILE_PATH)) % 250000 + 50000,
    DATEADD('hour', -(ABS(HASH(FILE_PATH)) % 72), CURRENT_TIMESTAMP()),
    OBJECT_CONSTRUCT(
        'response', OBJECT_CONSTRUCT(
            'vendor', VENDOR, 'receipt_date', RECEIPT_DATE::VARCHAR,
            'total_amount', TOTAL_AMOUNT::VARCHAR, 'currency', CURRENCY,
            'payment_method', PAYMENT_METHOD, 'category', CATEGORY,
            'line_items', LINE_ITEMS))::VARIANT
FROM RECEIPTS;

-- 04_cortex/01_extract_pipeline.sql -- procedure + views
-- (for brevity this deploy script creates the views; the procedure lives in
--  sql/04_cortex/01_extract_pipeline.sql and should be run separately when you
--  have real files on the stage.)

CREATE OR REPLACE VIEW V_SPEND_BY_CATEGORY
COMMENT = 'DEMO: Total spend per category (Expires: 2026-05-30)'
AS SELECT CATEGORY, COUNT(*) AS RECEIPT_COUNT, SUM(TOTAL_AMOUNT) AS TOTAL_SPEND,
          AVG(TOTAL_AMOUNT) AS AVG_SPEND
   FROM RECEIPTS WHERE CATEGORY IS NOT NULL GROUP BY CATEGORY;

CREATE OR REPLACE VIEW V_SPEND_BY_VENDOR
COMMENT = 'DEMO: Total spend per vendor (Expires: 2026-05-30)'
AS SELECT VENDOR, COUNT(*) AS RECEIPT_COUNT, SUM(TOTAL_AMOUNT) AS TOTAL_SPEND,
          MIN(RECEIPT_DATE) AS FIRST_RECEIPT, MAX(RECEIPT_DATE) AS LAST_RECEIPT
   FROM RECEIPTS WHERE VENDOR IS NOT NULL GROUP BY VENDOR;

-- 04_cortex/02_create_semantic_view.sql
USE SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS;

CREATE OR REPLACE SEMANTIC VIEW SV_RECEIPT_EXTRACTOR
    TABLES (
        RECEIPTS AS SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR.RECEIPTS
            PRIMARY KEY (FILE_PATH)
            WITH SYNONYMS ('receipts', 'expense receipts', 'expenses')
            COMMENT = 'One row per extracted employee expense receipt.'
    )
    FACTS (
        RECEIPTS.TOTAL_AMOUNT AS TOTAL_AMOUNT WITH SYNONYMS ('amount','total','spend')
            COMMENT = 'Grand total on the receipt.'
    )
    DIMENSIONS (
        RECEIPTS.VENDOR AS VENDOR WITH SYNONYMS ('merchant','supplier','payee')
            COMMENT = 'Vendor name as written on the receipt.',
        RECEIPTS.CATEGORY AS CATEGORY WITH SYNONYMS ('expense category','spend category','type')
            COMMENT = 'Category of expense: meals, travel, lodging, supplies, mileage, other.',
        RECEIPTS.PAYMENT_METHOD AS PAYMENT_METHOD WITH SYNONYMS ('card','payment','tender')
            COMMENT = 'Payment instrument.',
        RECEIPTS.CURRENCY AS CURRENCY WITH SYNONYMS ('currency code')
            COMMENT = 'ISO 4217 currency code.',
        RECEIPTS.RECEIPT_DATE AS RECEIPT_DATE WITH SYNONYMS ('date','purchase date','expense date')
            COMMENT = 'Calendar date on the receipt.',
        RECEIPTS.FILE_PATH AS FILE_PATH WITH SYNONYMS ('file','source file','receipt id')
            COMMENT = 'Stage-relative path, acts as the receipt id.'
    )
    METRICS (
        RECEIPTS.TOTAL_SPEND AS SUM(RECEIPTS.TOTAL_AMOUNT)
            WITH SYNONYMS ('spend','total spend') COMMENT = 'Sum of TOTAL_AMOUNT.',
        RECEIPTS.RECEIPT_COUNT AS COUNT(RECEIPTS.FILE_PATH)
            WITH SYNONYMS ('count of receipts') COMMENT = 'Receipt count.',
        RECEIPTS.AVG_RECEIPT_AMOUNT AS AVG(RECEIPTS.TOTAL_AMOUNT)
            WITH SYNONYMS ('average receipt') COMMENT = 'Average receipt amount.'
    )
    COMMENT = 'DEMO: Semantic view for Cortex Analyst over extracted receipts (Expires: 2026-05-30)';

-- Final summary (ONLY visible result in Run All)
SELECT
    'Deployment complete' AS status,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR.RECEIPTS) AS receipts_loaded,
    CURRENT_TIMESTAMP() AS completed_at;
