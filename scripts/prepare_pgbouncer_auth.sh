#!/bin/bash

PG_ISREADY="podman exec -it $1 pg_isready -U $2 -d $3"

until $PG_ISREADY
do
  echo "Waiting for postgres to start..."
  sleep 5
done

podman exec -it $1 psql -U $2 -d $3 -c "CREATE ROLE pgbouncer WITH LOGIN PASSWORD 'pgbouncer';"
podman exec -it $1 psql -U $2 -d $3 -c "REVOKE ALL PRIVILEGES ON SCHEMA public FROM pgbouncer;"
podman exec -it $1 psql -U $2 -d $3 -c "CREATE SCHEMA IF NOT EXISTS pgbouncer;"
podman exec -it $1 psql -U $2 -d $3 -c "REVOKE ALL PRIVILEGES ON SCHEMA pgbouncer FROM pgbouncer;"
podman exec -it $1 psql -U $2 -d $3 -c "GRANT USAGE ON SCHEMA pgbouncer TO pgbouncer;"
podman exec -it $1 psql -U $2 -d $3 -c "CREATE OR REPLACE FUNCTION pgbouncer.get_auth(username TEXT) RETURNS TABLE(username TEXT, password TEXT) AS \$\$ SELECT rolname::TEXT, rolpassword::TEXT FROM pg_authid WHERE pg_authid.rolcanlogin AND pg_authid.rolname <> 'pgbouncer' AND (pg_authid.rolvaliduntil IS NULL OR pg_authid.rolvaliduntil >= CURRENT_TIMESTAMP) AND pg_authid.rolname = \$1; \$\$ LANGUAGE SQL STABLE SECURITY DEFINER;"
podman exec -it $1 psql -U $2 -d $3 -c "REVOKE ALL ON FUNCTION pgbouncer.get_auth(username TEXT) FROM PUBLIC, pgbouncer;"
podman exec -it $1 psql -U $2 -d $3 -c "GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(username TEXT) TO pgbouncer;"

echo "PgBouncer Auth Preparation Complete"
