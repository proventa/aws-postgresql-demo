#!/bin/bash

PG_ISREADY="podman exec -it patroni-container pg_isready -U postgres"

until $PG_ISREADY
do
  echo "Waiting for postgres to start..."
  sleep 5
done

podman exec -it patroni-container psql -U postgres -c "CREATE ROLE pgbouncer WITH LOGIN PASSWORD 'pgbouncer';"
podman exec -it patroni-container psql -U postgres -c "REVOKE ALL PRIVILEGES ON SCHEMA public FROM pgbouncer;"
podman exec -it patroni-container psql -U postgres -c "CREATE SCHEMA IF NOT EXISTS pgbouncer;"
podman exec -it patroni-container psql -U postgres -c "REVOKE ALL PRIVILEGES ON SCHEMA pgbouncer FROM pgbouncer;"
podman exec -it patroni-container psql -U postgres -c "GRANT USAGE ON SCHEMA pgbouncer TO pgbouncer;"
podman exec -it patroni-container psql -U postgres -c "CREATE OR REPLACE FUNCTION pgbouncer.get_auth(username TEXT) RETURNS TABLE(username TEXT, password TEXT) AS \$\$ SELECT rolname::TEXT, rolpassword::TEXT FROM pg_authid WHERE NOT pg_authid.rolsuper AND NOT pg_authid.rolreplication AND pg_authid.rolcanlogin AND pg_authid.rolname <> 'pgbouncer' AND (pg_authid.rolvaliduntil IS NULL OR pg_authid.rolvaliduntil >= CURRENT_TIMESTAMP) AND pg_authid.rolname = \$1; \$\$ LANGUAGE SQL STABLE SECURITY DEFINER;"
podman exec -it patroni-container psql -U postgres -c "REVOKE ALL ON FUNCTION pgbouncer.get_auth(username TEXT) FROM PUBLIC, pgbouncer;"
podman exec -it patroni-container psql -U postgres -c "GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(username TEXT) TO pgbouncer;"

echo "PgBouncer Auth Preparation Complete"
