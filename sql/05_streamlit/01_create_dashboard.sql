/*==============================================================================
STREAMLIT - Expense Rodeo (Receipt Explorer)
Deploys the Streamlit app directly from the Git repository -- no manual PUT
required.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.EXPENSE_RODEO;
USE WAREHOUSE SFE_EXPENSE_RODEO_WH;

CREATE OR REPLACE STREAMLIT RECEIPT_EXPLORER
  ROOT_LOCATION = '@SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO/branches/main/streamlit'
  MAIN_FILE     = 'streamlit_app.py'
  QUERY_WAREHOUSE = SFE_EXPENSE_RODEO_WH
  COMMENT = 'DEMO: Receipt Explorer dashboard (Expires: 2026-05-30)';

SHOW STREAMLITS LIKE 'RECEIPT_EXPLORER';
