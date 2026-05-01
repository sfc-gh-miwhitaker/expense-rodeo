/*==============================================================================
SETUP - Expense Rodeo
Creates stage, tables, and other non-shared objects.
Expected to be invoked via EXECUTE IMMEDIATE FROM deploy_all.sql (schema,
warehouse, and database are created there).
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

USE WAREHOUSE SFE_EXPENSE_RODEO_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.EXPENSE_RODEO;

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
    AVG_CONFIDENCE  NUMBER(4,3),
    EXTRACTED_AT    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Typed receipt fact table (Expires: 2026-05-30)';
