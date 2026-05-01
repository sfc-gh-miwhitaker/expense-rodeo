/*==============================================================================
TEARDOWN - Expense Rodeo
Drops project-specific objects. Leaves shared infrastructure in place
(SNOWFLAKE_EXAMPLE db, GIT_REPOS + SEMANTIC_MODELS schemas, GIT API integration).
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

USE ROLE SYSADMIN;

DROP STREAMLIT  IF EXISTS SNOWFLAKE_EXAMPLE.EXPENSE_RODEO.RECEIPT_EXPLORER;
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_EXPENSE_RODEO;
DROP SCHEMA     IF EXISTS SNOWFLAKE_EXAMPLE.EXPENSE_RODEO CASCADE;
DROP WAREHOUSE  IF EXISTS SFE_EXPENSE_RODEO_WH;
DROP GIT REPOSITORY IF EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO;

SELECT 'Teardown complete' AS status;
