/*==============================================================================
SEMANTIC VIEW - Expense Rodeo
Cortex Analyst-ready view over the RECEIPTS fact.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-30
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS;

CREATE OR REPLACE SEMANTIC VIEW SV_RECEIPT_EXTRACTOR
    TABLES (
        RECEIPTS AS SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR.RECEIPTS
            PRIMARY KEY (FILE_PATH)
            WITH SYNONYMS ('receipts', 'expense receipts', 'expenses')
            COMMENT = 'One row per extracted employee expense receipt.'
    )
    FACTS (
        RECEIPTS.TOTAL_AMOUNT AS TOTAL_AMOUNT
            WITH SYNONYMS ('amount', 'total', 'receipt total', 'spend')
            COMMENT = 'Grand total on the receipt in the receipt currency.'
    )
    DIMENSIONS (
        RECEIPTS.VENDOR AS VENDOR
            WITH SYNONYMS ('merchant', 'supplier', 'payee')
            COMMENT = 'Vendor name as written on the receipt.',
        RECEIPTS.CATEGORY AS CATEGORY
            WITH SYNONYMS ('expense category', 'spend category', 'type')
            COMMENT = 'Category of expense: meals, travel, lodging, supplies, mileage, other.',
        RECEIPTS.PAYMENT_METHOD AS PAYMENT_METHOD
            WITH SYNONYMS ('card', 'payment', 'tender')
            COMMENT = 'Payment instrument -- card last-4, cash, or other.',
        RECEIPTS.CURRENCY AS CURRENCY
            WITH SYNONYMS ('currency code')
            COMMENT = 'ISO 4217 currency code.',
        RECEIPTS.RECEIPT_DATE AS RECEIPT_DATE
            WITH SYNONYMS ('date', 'purchase date', 'expense date')
            COMMENT = 'Calendar date on the receipt.',
        RECEIPTS.FILE_PATH AS FILE_PATH
            WITH SYNONYMS ('file', 'source file', 'receipt id')
            COMMENT = 'Stage-relative path of the source file -- acts as the receipt id.'
    )
    METRICS (
        RECEIPTS.TOTAL_SPEND AS SUM(RECEIPTS.TOTAL_AMOUNT)
            WITH SYNONYMS ('spend', 'total spend', 'total amount')
            COMMENT = 'Sum of TOTAL_AMOUNT across receipts.',
        RECEIPTS.RECEIPT_COUNT AS COUNT(RECEIPTS.FILE_PATH)
            WITH SYNONYMS ('receipts', 'count of receipts', 'number of receipts')
            COMMENT = 'Number of receipts.',
        RECEIPTS.AVG_RECEIPT_AMOUNT AS AVG(RECEIPTS.TOTAL_AMOUNT)
            WITH SYNONYMS ('average receipt', 'avg spend')
            COMMENT = 'Average receipt amount.'
    )
    COMMENT = 'DEMO: Semantic view for Cortex Analyst over extracted receipts (Expires: 2026-05-30)';

SELECT 'Semantic view ready' AS status;
