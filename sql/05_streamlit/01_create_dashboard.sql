/*==============================================================================
STREAMLIT - Receipt Explorer
Deploys the dashboard directly from the files in streamlit/ via stage upload.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR;
USE WAREHOUSE SFE_RECEIPT_EXTRACTOR_WH;

-- Stage to hold the Streamlit source files.
CREATE STAGE IF NOT EXISTS RECEIPT_EXPLORER_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'DEMO: Source stage for RECEIPT_EXPLORER Streamlit (Expires: 2026-05-30)';

-- NOTE: Upload the Streamlit source from the repo before running the CREATE
-- STREAMLIT statement. From SnowSQL or snow CLI:
--
--   PUT file://streamlit/streamlit_app.py @RECEIPT_EXPLORER_STAGE
--     AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--
-- Once the file is on the stage, (re)create the Streamlit object:

CREATE OR REPLACE STREAMLIT RECEIPT_EXPLORER
  ROOT_LOCATION = '@SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR.RECEIPT_EXPLORER_STAGE'
  MAIN_FILE     = 'streamlit_app.py'
  QUERY_WAREHOUSE = SFE_RECEIPT_EXTRACTOR_WH
  COMMENT = 'DEMO: Receipt Explorer dashboard (Expires: 2026-05-30)';

SHOW STREAMLITS LIKE 'RECEIPT_EXPLORER';
SELECT 'Streamlit dashboard ready' AS status;
