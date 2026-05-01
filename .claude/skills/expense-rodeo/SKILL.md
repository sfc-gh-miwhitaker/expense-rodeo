---
name: expense-rodeo
description: "Receipt extraction demo: land PDFs/images in a stage, AI_EXTRACT into a structured RECEIPTS table, explore via Streamlit and Cortex Analyst. Use when: extending the receipt extractor, adding new extracted fields, adding a new category, debugging AI_EXTRACT on mixed file types."
---

# Expense Rodeo

## Purpose

A compact demo that turns unstructured expense receipts (PDF + JPG/PNG + TIFF)
into a typed `RECEIPTS` fact table using a single `AI_EXTRACT` call. Backs a
Streamlit explorer and a Cortex Analyst semantic view.

## Architecture

```
RECEIPTS_STAGE -> AI_EXTRACT -> RECEIPTS_RAW -> RECEIPTS -> {views, SV, Streamlit}
```

- `RECEIPTS_STAGE` has a directory table and server-side encryption (required by
  AI file functions).
- `RECEIPTS_RAW` stores the raw VARIANT response so we can re-shape without
  re-calling Cortex.
- `RECEIPTS` is the typed fact; `line_items` remains VARIANT.

## Snowflake Objects

- Database: `SNOWFLAKE_EXAMPLE`
- Schema:   `EXPENSE_RODEO`
- Warehouse: `SFE_EXPENSE_RODEO_WH`
- Stage:    `RECEIPTS_STAGE`
- Tables:   `RECEIPTS_RAW`, `RECEIPTS`
- Views:    `V_SPEND_BY_CATEGORY`, `V_SPEND_BY_VENDOR`
- Semantic: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_EXPENSE_RODEO`
- Streamlit: `RECEIPT_EXPLORER`
- Git repo: `SNOWFLAKE_EXAMPLE.GIT_REPOS.EXPENSE_RODEO_REPO`
- API integration: `SFE_GIT_API_INTEGRATION` (shared, public repos)

## Key Files

| Path | Role |
|------|------|
| `deploy_all.sql` | Snowsight Run All entrypoint |
| `teardown_all.sql` | Drops schema, warehouse, semantic view |
| `sql/01_setup/01_create_schema.sql` | Database, schema, warehouse, stage, tables |
| `sql/02_data/01_load_sample_data.sql` | PUTs sample receipts, refreshes stage |
| `sql/04_cortex/01_extract_pipeline.sql` | `AI_EXTRACT` + flattening + procedure |
| `sql/04_cortex/02_create_semantic_view.sql` | `SV_EXPENSE_RODEO` |
| `sql/05_streamlit/01_create_dashboard.sql` | Deploys Streamlit from git |
| `streamlit/streamlit_app.py` | Dashboard source |

## Extension Playbook: adding a new extracted field

1. Edit `sql/04_cortex/01_extract_pipeline.sql`.
2. Add a key to the `responseFormat` object passed to `AI_EXTRACT`, e.g.
   `'tax_amount': 'Total tax on the receipt as a number'`.
3. Add a new column to the `CREATE OR REPLACE TABLE RECEIPTS` DDL and a pull
   expression of the form
   `extraction:response:tax_amount::STRING AS tax_amount_raw` plus a typed
   `TRY_TO_NUMBER(...)` column.
4. Re-run `CALL SP_RECEIPT_EXTRACT_ALL();` (or re-run the whole script).
5. If the field should be available to Cortex Analyst, add it to
   `sql/04_cortex/02_create_semantic_view.sql` as a dimension or fact with a
   rich description and synonyms.
6. Surface it in `streamlit/streamlit_app.py` in the "Extracted fields" panel.

## Extension Playbook: adding a new spend category

1. Update the prompt string for the `category` field in
   `sql/04_cortex/01_extract_pipeline.sql` to include the new allowed value,
   e.g. `"One of: meals, travel, lodging, supplies, mileage, other"`.
2. Re-run the extract procedure.
3. No semantic-view change is needed -- the dimension is free-text.

## Extension Playbook: tuning extraction for dense / small-text receipts

`SP_RECEIPT_EXTRACT_ALL` takes a `SCALE_FACTOR` argument wired to
`AI_EXTRACT(config => {'scale_factor': :SCALE_FACTOR})`. Valid range is
1.0 - 4.0 (docs). Higher values improve OCR on dense or small-print receipts
at the cost of more tokens and fewer pages per call.

```sql
-- Re-run with 2x scale for a small/dense batch
CALL SP_RECEIPT_EXTRACT_ALL(2.0);
```

Use `V_LOW_CONFIDENCE_RECEIPTS` to find candidates that need re-extraction.

## Gotchas

- **Streamlit version pinning** -- SiS warehouse runtimes default to an old
  Streamlit when no `environment.yml` is shipped, which breaks `hide_index`,
  `column_config`, and other newer APIs. We pin `streamlit=1.52.2` in
  `streamlit/environment.yml`. If you PUT the app to a different location,
  ship `environment.yml` alongside `streamlit_app.py`.
- **`use_container_width` is deprecated** -- don't add it to new Streamlit
  code; stretch is the default in 1.52+.
- **`CREATE STREAMLIT ... ROOT_LOCATION` forces warehouse runtime** -- the
  docs note that apps created with `ROOT_LOCATION` cannot use the container
  runtime. Pin Streamlit via `environment.yml` to stay on a known version.
- **Stage refresh** -- after `PUT`ing new files you **must** call
  `ALTER STAGE RECEIPTS_STAGE REFRESH` before the directory table returns the
  new rows. Missing this will silently process zero new files.
- **SSE encryption** -- AI_EXTRACT requires server-side encryption. The stage
  is created with `ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')`; do not recreate it
  without that clause.
- **Cross-region inference** -- AI_EXTRACT may need
  `ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_US'` if the account
  region lacks native availability. Ship the demo in a native region when
  possible.
- **Warehouse size** -- keep at XSMALL; docs note larger warehouses do not
  speed up AI file functions and only raise cost.
- **Currency parsing** -- AI_EXTRACT can return strings like `$123.45`. The
  flatten step uses `TRY_TO_NUMBER` with an explicit numeric scale; rows that
  fail parsing land as NULL rather than blocking the pipeline.
- **Directory-table VARIANT drift** -- if a file fails to parse, the VARIANT
  row still lands in `RECEIPTS_RAW` with NULLs; the `RECEIPTS` table skips any
  row where `extraction:response` is NULL.
- **Line-items shape** -- `AI_EXTRACT` table extraction returns columns as
  parallel arrays (`{description: [...], quantity: [...], ...}`). The MERGE in
  `01_extract_pipeline.sql` transposes those back into an array of row-shaped
  objects for the typed `LINE_ITEMS` VARIANT. If you add a column, update the
  `column_ordering`, the schema block, AND the ARRAY_AGG transpose.
- **Confidence scores** -- `scores => TRUE` returns one score per entity
  field and one aggregate score per table field (`line_items`). The code
  averages seven score fields; adding/removing an extracted field means
  updating the divisor.
