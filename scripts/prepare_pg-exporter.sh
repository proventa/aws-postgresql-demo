#!/bin/bash

cat > /usr/local/share/web-config.yml <<EOF
tls_server_config:
    cert_file: /etc/ssl/self-certs/proventa-client-cert.pem
    key_file: /etc/ssl/self-certs/proventa-client-cert-key.pem
    client_auth_type: "RequireAndVerifyClientCert"
    client_ca_file: /etc/ssl/self-certs/proventa-root-ca.pem
EOF

chmod 644 /usr/local/share/web-config.yml

cat > /usr/local/share/postgres_exporter.yml <<EOF
auth_modules:
  superuser:
    type: userpass
    userpass:
      username: postgres
      password: zalando
    options:
      sslmode: disable
EOF

chmod 644 /usr/local/share/postgres_exporter.yml