# Sample data

Drop real receipt files here (`*.pdf`, `*.jpg`, `*.jpeg`, `*.png`, `*.tif`,
`*.tiff`) and run the PUT commands from `../docs/user-guide.md` to ingest them.

The demo ships with synthetic rows loaded directly into `RECEIPTS` by
`sql/02_data/01_load_sample_data.sql` so the dashboard is immediately usable
without any real files. Live `AI_EXTRACT` output replaces those rows once you
call `SP_RECEIPT_EXTRACT_ALL()`.
