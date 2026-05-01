![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--05--30-orange)

# Expense Rodeo

> DEMONSTRATION PROJECT - EXPIRES: 2026-05-30
> This demo uses Snowflake features current as of April 2026.
> After expiration, this repository will be archived.

**Pair-programmed by:** SE Community + Cortex Code
**Purpose:** Reference implementation for AI-driven extraction of employee expense receipts (mixed PDFs and images) into a structured fact table.
**Created:** 2026-04-30 | **Expires:** 2026-05-30 (30 days) | **Status:** ACTIVE

## First Time Here?

1. **Deploy** - Open `deploy_all.sql` in Snowsight, click Run All (~2 minutes).
2. **Open the dashboard** - Find `RECEIPT_EXPLORER` under Streamlit in Snowsight.
3. **Pick a receipt** - Browse the extracted fields side-by-side with the original file.
4. **Ask questions** - Point Cortex Analyst at `SV_RECEIPT_EXTRACTOR` for natural-language spend queries.
5. **Cleanup** - Run `teardown_all.sql` when done.

## What It Does

Land employee expense receipts (PDF, JPG, PNG, TIFF) in a single Snowflake stage.
A single `AI_EXTRACT` call walks the directory table, pulls structured fields
(vendor, date, total, currency, payment method, category, line items) from each
file, and writes them to a typed `RECEIPTS` fact table. The Streamlit explorer
and a semantic view give finance users both a visual review UI and natural
language analytics.

## What Gets Created

| Object | Type | Purpose |
|--------|------|---------|
| `SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR` | Schema | All project objects |
| `SFE_RECEIPT_EXTRACTOR_WH` | Warehouse (XS) | Compute for extraction + UI |
| `RECEIPTS_STAGE` | Stage | Landing zone for receipts (directory table, SSE) |
| `RECEIPTS_RAW` | Table | Raw `AI_EXTRACT` output per file (VARIANT) |
| `RECEIPTS` | Table | Flattened, typed fact table |
| `V_SPEND_BY_CATEGORY` | View | Rollup for dashboard |
| `V_SPEND_BY_VENDOR` | View | Rollup for dashboard |
| `SV_RECEIPT_EXTRACTOR` | Semantic View | Cortex Analyst NL analytics |
| `RECEIPT_EXPLORER` | Streamlit | File-preview and KPI dashboard |

## Key Features

- **AI_EXTRACT on TO_FILE** - one function call per receipt, no pre-OCR step
- **Heterogeneous inputs** - same query handles PDFs and image formats
- **Directory table driven** - batch processing keyed off `DIRECTORY(@STAGE)`
- **Side-by-side preview** - Streamlit shows the source file via presigned URL
  next to the extracted fields for auditability

## Estimated Demo Costs

| Component | Size | Est. Credits |
|-----------|------|--------------|
| Warehouse | XSMALL | ~1 credit / hour of active use |
| AI_EXTRACT | Per-page billing | ~0.001 credits / page |
| Cortex Analyst | Per-query | ~0.01 credits / query |
| Storage | <1 MB sample data | Negligible |

**Edition required:** Enterprise (Cortex AI functions, Cortex Analyst).

## Development Tools

This project follows the SE Community project standards:

- `AGENTS.md` - per-project conventions for Cortex Code / Cursor
- `.claude/skills/expense-rodeo/SKILL.md` - extension playbook for this demo
- Global rules in `~/.claude/CLAUDE.md` apply automatically

## Project Layout

```
expense-rodeo/
  deploy_all.sql                 # Snowsight entry point
  teardown_all.sql               # Removes everything
  sql/                           # Ordered deployment scripts
  streamlit/streamlit_app.py     # Dashboard source
  sample_data/                   # Example receipts
  docs/                          # User + architecture docs
  diagrams/                      # Mermaid diagrams
```
