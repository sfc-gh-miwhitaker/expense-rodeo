/*==============================================================================
SETUP - Expense Rodeo
Creates schema, stage, and empty tables.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

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

-- Stage for raw receipt files (PDFs + images). Directory table + SSE are
-- required for AI_EXTRACT / TO_FILE.
CREATE STAGE IF NOT EXISTS RECEIPTS_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'DEMO: Landing zone for employee expense receipts (Expires: 2026-05-30)';

-- Raw AI_EXTRACT output, one row per file.
CREATE TABLE IF NOT EXISTS RECEIPTS_RAW (
    FILE_PATH      VARCHAR NOT NULL,
    FILE_SIZE      NUMBER,
    LAST_MODIFIED  TIMESTAMP_TZ,
    EXTRACTION     VARIANT,
    EXTRACTED_AT   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Raw AI_EXTRACT response per receipt file (Expires: 2026-05-30)';

-- Typed fact table derived from RECEIPTS_RAW.
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

SELECT 'Setup complete' AS status;
