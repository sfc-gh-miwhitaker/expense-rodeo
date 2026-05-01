/*==============================================================================
TEARDOWN ALL - Expense Rodeo
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
INSTRUCTIONS: Open in Snowsight -> Click Run All
==============================================================================*/

USE ROLE SYSADMIN;

DROP STREAMLIT  IF EXISTS SNOWFLAKE_EXAMPLE.EXPENSE_RODEO.RECEIPT_EXPLORER;
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_EXPENSE_RODEO;
DROP SCHEMA     IF EXISTS SNOWFLAKE_EXAMPLE.EXPENSE_RODEO CASCADE;
DROP WAREHOUSE  IF EXISTS SFE_EXPENSE_RODEO_WH;
DROP GIT REPOSITORY IF EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO;

SELECT 'Teardown complete' AS status;
