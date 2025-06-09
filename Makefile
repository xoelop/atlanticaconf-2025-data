include .env
serve:
	open http://localhost:8000/migration-presentation.html && python -m http.server 8000	
	
chprod:
	@clickhouse client --host ${PROD_CLICKHOUSE_HOST} --user ${PROD_CLICKHOUSE_USER} --password ${PROD_CLICKHOUSE_PASSWORD} --database default --secure --reject_expensive_hyperscan_regexps=1 --max_query_size='100M' --max_ast_elements='500k' --format=PrettyCompactMonoBlock --enable_filesystem_cache=0 --max_threads=50

pgprod:
	@psql ${PG_URL}