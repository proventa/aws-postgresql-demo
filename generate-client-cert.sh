#!/bin/bash

# Make sure bin and certs directories exist and clean
mkdir -p /tmp/bin && rm -f /tmp/bin/cfssl* && rm -rf certs && mkdir -p certs

# Download cfssl binaries
curl -L https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o /tmp/bin/cfssl
chmod +x /tmp/bin/cfssl

# Download cfssljson binaries
curl -L https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o /tmp/bin/cfssljson
chmod +x /tmp/bin/cfssljson

ip_address=$(hostname -I | awk '{print $1}')

cat > /etc/ssl/etcd-certs/proventa-etcd-client-cert-csr.json <<EOF
{
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "O": "Proventa",
      "OU": "AWS Postgres Demo",
      "L": "Frankfurt",
      "ST": "Hesse",
      "C": "Germany"
    }
  ],
  "CN": "proventa-etcd-client-cert",
  "hosts": [
    "127.0.0.1",
    "localhost",
    "$ip_address"
  ]
}
EOF

/tmp/bin/cfssl gencert \
  --ca /etc/ssl/etcd-certs/proventa-etcd-root-ca.pem \
  --ca-key /etc/ssl/etcd-certs/proventa-etcd-root-ca-key.pem \
  --config /etc/ssl/etcd-certs/proventa-etcd-gencert-config.json \
  /etc/ssl/etcd-certs/proventa-etcd-client-cert-csr.json | /tmp/bin/cfssljson --bare /etc/ssl/etcd-certs/proventa-etcd-client-cert

chmod 644 /etc/ssl/etcd-certs/proventa-etcd-client-cert.pem
chmod 644 /etc/ssl/etcd-certs/proventa-etcd-client-cert-key.pem