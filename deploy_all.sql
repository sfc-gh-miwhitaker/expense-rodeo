/*==============================================================================
DEPLOY ALL - Expense Rodeo
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30

INSTRUCTIONS:
  Open this file in Snowsight -> Click "Run All".
  ~2 minutes. Everything else (schema, stage, tables, procedure, semantic view,
  Streamlit) is fetched from Git and executed in order.

PREREQUISITES: None. Shared infrastructure is created inline with IF NOT EXISTS.
==============================================================================*/

-- 1. Expiration check (informational -- warns but does not block)
SELECT
    '2026-05-30'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) < 0
            THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) <= 7
            THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-30'::DATE) || ' days remaining'
    END AS demo_status;

-- 2. Shared infrastructure (idempotent)
USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for SE Community public demos';

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SYSADMIN;
GRANT USAGE ON INTEGRATION SFE_GIT_API_INTEGRATION TO ROLE SYSADMIN;

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for SE Community demo projects';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared schema for Cortex Analyst semantic views';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.EXPENSE_RODEO
  COMMENT = 'DEMO: Expense Rodeo project (Expires: 2026-05-30)';

CREATE WAREHOUSE IF NOT EXISTS SFE_EXPENSE_RODEO_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'DEMO: Expense Rodeo compute (Expires: 2026-05-30)';

USE WAREHOUSE SFE_EXPENSE_RODEO_WH;

-- 3. Git repository (public -- no GIT_CREDENTIALS needed)
CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/expense-rodeo.git'
  COMMENT = 'Public repo for the Expense Rodeo demo';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO FETCH;

-- 4. Execute project scripts from Git, in order
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO/branches/main/sql/01_setup/01_create_schema.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO/branches/main/sql/02_data/01_load_sample_data.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO/branches/main/sql/04_cortex/01_extract_pipeline.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO/branches/main/sql/04_cortex/02_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO/branches/main/sql/05_streamlit/01_create_dashboard.sql';

-- 5. Final summary (ONLY visible result in Run All)
SELECT
    'Deployment complete' AS status,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.EXPENSE_RODEO.RECEIPTS) AS receipts_loaded,
    'Open Projects > Streamlit > RECEIPT_EXPLORER to start' AS next_step,
    CURRENT_TIMESTAMP() AS completed_at;
