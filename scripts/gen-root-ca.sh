#!/bin/bash

# If proventa-etcd-root-ca.pem and proventa-etcd-root-ca-key.pem already exist, then skip this step
if [ -f ../certs/proventa-etcd-root-ca.pem ] && [ -f ../certs/proventa-etcd-root-ca-key.pem ]; then
  echo "Root CA already exists. Skipping root CA generation."
  exit 0
fi

# Make sure bin and certs directories exist and clean
mkdir -p ../bin && rm -f ../bin/cfssl* && rm -rf ../certs && mkdir -p ../certs


# Download cfssl binaries
curl -L https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o ../bin/cfssl
chmod +x ../bin/cfssl

# Download cfssljson binaries
curl -L https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o ../bin/cfssljson
chmod +x ../bin/cfssljson

# Generate root CA certificate bundle (Public Certificate and Private Key)
cat > ../certs/proventa-etcd-root-ca-csr.json <<EOF
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
  "CN": "proventa-etcd-root-ca"
}
EOF

./../bin/cfssl gencert --initca=true ../certs/proventa-etcd-root-ca-csr.json | ./../bin/cfssljson --bare ../certs/proventa-etcd-root-ca

cat > ../certs/proventa-etcd-gencert-config.json <<EOF
{
  "signing": {
    "default": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "87600h"
    }
  }
}
EOF
