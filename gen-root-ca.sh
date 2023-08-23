#!/bin/bash

# If proventa-etcd-root-ca.pem and proventa-etcd-root-ca-key.pem already exist, then skip this step
if [ -f certs/proventa-etcd-root-ca.pem ] && [ -f certs/proventa-etcd-root-ca-key.pem ]; then
  echo "Root CA already exists. Skipping root CA generation."
  exit 0
fi

# Make sure certs directory exist and clean
rm -rf certs && mkdir -p certs

# Generate root CA certificate bundle (Public Certificate and Private Key)
cat > certs/proventa-etcd-root-ca-csr.json <<EOF
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

IMAGES=$(podman images | grep cfssl | awk '{print $1}')

# If cfssl imagae is not present, then pull it
if [ -z "$IMAGES" ]; then
  echo "Pulling cfssl image"
  podman pull cfssl/cfssl
fi

podman run --rm -v ./certs/proventa-etcd-root-ca-csr.json:/proventa-etcd-root-ca-csr.json cfssl/cfssl gencert -initca /proventa-etcd-root-ca-csr.json |  cfssljson --bare ./certs/proventa-etcd-root-ca
