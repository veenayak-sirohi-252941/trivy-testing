FROM postgres:15-bookworm

# Scripts in this directory are executed by the official PostgreSQL entrypoint
# when the database data directory is initialized for the first time.
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql
