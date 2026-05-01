# Expense Rodeo -- User Guide

## Prerequisites

- Snowflake Enterprise edition (Cortex AI functions + Cortex Analyst)
- A role with `SNOWFLAKE.CORTEX_USER` (the deploy script grants this to
  `SYSADMIN` automatically)

## Deploy

1. Open `deploy_all.sql` in Snowsight.
2. Click Run All. The script provisions the schema, stage, tables, views,
   stored procedure, and semantic view, and seeds 12 synthetic receipts.
3. Expected runtime: under 2 minutes on XSMALL.

## Process real receipts

```sql
-- From SnowSQL / snow CLI where you have access to the project files:
PUT file://sample_data/*.pdf @SNOWFLAKE_EXAMPLE.EXPENSE_RODEO.RECEIPTS_STAGE
  AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://sample_data/*.jpg @SNOWFLAKE_EXAMPLE.EXPENSE_RODEO.RECEIPTS_STAGE
  AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- In Snowsight:
USE SCHEMA SNOWFLAKE_EXAMPLE.EXPENSE_RODEO;
ALTER STAGE RECEIPTS_STAGE REFRESH;
CALL SP_RECEIPT_EXTRACT_ALL();
```

## Open the dashboard

Projects -> Streamlit -> `RECEIPT_EXPLORER`.

- Pick a receipt from the left-hand list; the right pane shows the source
  image (via presigned URL) next to extracted fields and line items.
- Sidebar filters narrow by category and date range.
- Bottom charts show spend by category and top vendors.

## Ask Cortex Analyst

The semantic view is at
`SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_EXPENSE_RODEO`. Example questions:

- "What was total spend last week?"
- "Top 5 vendors by total amount."
- "Show me meals spend by day."

## Tear down

Open `teardown_all.sql` in Snowsight, Run All. It drops the schema, warehouse,
and semantic view but leaves the shared `SNOWFLAKE_EXAMPLE` database in place.
