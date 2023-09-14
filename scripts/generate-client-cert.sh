#!/bin/bash

# Make sure bin and certs directories exist and clean
mkdir -p ~/bin && rm -f ~/bin/cfssl*

# Download cfssl and cfssljson binaries
curl -L -o ~/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -L -o ~/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x ~/bin/{cfssl,cfssljson}

export PATH=$PATH:~/bin

ip_address=$(hostname -I | awk '{print $1}')

cat > /etc/ssl/self-certs/proventa-client-cert-csr.json <<EOF
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
  "CN": "proventa-client-cert",
  "hosts": [
    "127.0.0.1",
    "localhost",
    "$ip_address"
  ]
}
EOF

cfssl gencert \
  --ca /etc/ssl/self-certs/proventa-root-ca.pem \
  --ca-key /etc/ssl/self-certs/proventa-root-ca-key.pem \
  --config /etc/ssl/self-certs/proventa-gencert-config.json \
  /etc/ssl/self-certs/proventa-client-cert-csr.json | cfssljson --bare /etc/ssl/self-certs/proventa-client-cert

chmod 644 /etc/ssl/self-certs/proventa-client-cert.pem
chmod 644 /etc/ssl/self-certs/proventa-client-cert-key.pem