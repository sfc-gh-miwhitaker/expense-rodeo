/*==============================================================================
TEARDOWN ALL - Expense Rodeo
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
INSTRUCTIONS: Open in Snowsight -> Click Run All
==============================================================================*/

USE ROLE SYSADMIN;

DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR.RECEIPT_EXPLORER;
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_RECEIPT_EXTRACTOR;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR CASCADE;
DROP WAREHOUSE IF EXISTS SFE_RECEIPT_EXTRACTOR_WH;

SELECT 'Teardown complete' AS status;
