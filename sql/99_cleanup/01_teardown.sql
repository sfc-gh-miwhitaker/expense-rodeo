/*==============================================================================
TEARDOWN - Expense Rodeo
Drops everything created by this demo. Leaves shared SNOWFLAKE_EXAMPLE database
and SEMANTIC_MODELS schema in place.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

USE ROLE SYSADMIN;

DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR.RECEIPT_EXPLORER;
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_RECEIPT_EXTRACTOR;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR CASCADE;
DROP WAREHOUSE IF EXISTS SFE_RECEIPT_EXTRACTOR_WH;

SELECT 'Teardown complete' AS status;
