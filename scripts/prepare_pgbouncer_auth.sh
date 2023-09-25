#!/bin/bash

PG_ISREADY="podman exec -it $1 pg_isready -U $2 -d $3"

until $PG_ISREADY
do
  echo "Waiting for postgres to start..."
  sleep 5
done

echo "Postgres is ready"

cat <<EOF | podman exec -it $1 psql -U $2 -d $3
CREATE ROLE pgbouncer WITH LOGIN PASSWORD 'pgbouncer';

REVOKE ALL PRIVILEGES ON SCHEMA public FROM pgbouncer;

CREATE SCHEMA IF NOT EXISTS pgbouncer;

REVOKE ALL PRIVILEGES ON SCHEMA pgbouncer FROM pgbouncer;

GRANT USAGE ON SCHEMA pgbouncer TO pgbouncer;

CREATE OR REPLACE FUNCTION pgbouncer.get_auth(username TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS \$\$ 
SELECT rolname::TEXT, rolpassword::TEXT FROM pg_authid 
WHERE pg_authid.rolcanlogin AND
pg_authid.rolname <> 'pgbouncer' AND
(pg_authid.rolvaliduntil IS NULL OR pg_authid.rolvaliduntil >= CURRENT_TIMESTAMP) AND
pg_authid.rolname = \$1; 
\$\$ LANGUAGE SQL STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION pgbouncer.get_auth(username TEXT) FROM PUBLIC, pgbouncer;

GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(username TEXT) TO pgbouncer;

\q
EOF

echo "PgBouncer Auth Preparation Complete"

exit 0