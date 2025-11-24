#!/bin/bash
# import_keys.sh

CSV_FILE="${1:-keys.csv}"  # use your own file or keys.csv by default
DB_FILE="${2:-data/sqlite/keys.db}"  # usa your own sqlite3 db file or data/sqlite/keys.db by default

sqlite3 $DB_FILE << SQL
CREATE TEMP TABLE IF NOT EXISTS import_temp(grok_key TEXT, daily_spend_limit_usd REAL DEFAULT 3.0);
DELETE FROM import_temp;
.mode csv
.import $CSV_FILE import_temp

INSERT INTO api_keys (grok_key, status, daily_spend_limit_usd, daily_request_limit, created_at, total_spent_usd, total_requests)
SELECT 
    grok_key,
    'available',
    COALESCE(daily_spend_limit_usd, 3.0),
    1000,
    datetime(),
    0,
    0
FROM import_temp;

DROP TABLE import_temp;


SELECT 'Imported/updated: ' || changes() || ' keys. Available keys: ' || 
       (SELECT COUNT(*) FROM api_keys WHERE status = 'available') AS resultado;
SQL