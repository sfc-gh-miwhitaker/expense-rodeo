# Expense Rodeo -- Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

```
RECEIPTS_STAGE (directory table, SSE)
   |-- PDFs, JPGs, PNGs, TIFFs
   v
AI_EXTRACT(TO_FILE(...), responseFormat)
   v
RECEIPTS_RAW (VARIANT)   ->   RECEIPTS (typed)
                               |
                               +--> V_SPEND_BY_CATEGORY, V_SPEND_BY_VENDOR
                               +--> SV_EXPENSE_RODEO (semantic view)
                               +--> RECEIPT_EXPLORER (Streamlit)
```

One Snowflake object per layer. No streams or tasks; extraction is manual or
cron-driven from outside Snowflake.

## Snowflake Environment

- Database: `SNOWFLAKE_EXAMPLE`
- Schema:   `EXPENSE_RODEO`
- Warehouse: `SFE_EXPENSE_RODEO_WH` (XSMALL)
- Stage:    `@SNOWFLAKE_EXAMPLE.EXPENSE_RODEO.RECEIPTS_STAGE`

## Conventions

- All SQL files live in `sql/NN_phase/NN_action.sql`; `deploy_all.sql` chains
  them in numeric order.
- Tables use no prefix (not `RAW_`, not `STG_`) -- there are only two, and the
  suffix `_RAW` denotes the VARIANT landing table.
- `RECEIPTS.line_items` stays as VARIANT on purpose; callers flatten when
  needed.
- Receipts live in `sample_data/` and are uploaded via `PUT` in
  `02_data/01_load_sample_data.sql`. After `PUT`, always call
  `ALTER STAGE RECEIPTS_STAGE REFRESH` before querying the directory.

## Key Commands

```sh
# Deploy everything from Snowsight
#   open deploy_all.sql, Run All

# Re-extract after dropping new receipts into the stage
#   CALL SP_RECEIPT_EXTRACT_ALL();  (see sql/04_cortex/01_extract_pipeline.sql)

# Tear down
#   open teardown_all.sql, Run All
```
