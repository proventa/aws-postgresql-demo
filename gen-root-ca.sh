# Make sure bin and certs directories exist and clean
mkdir -p bin && rm -f bin/cfssl* && rm -rf certs && mkdir -p certs

# Download cfssl binaries
curl -L https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o bin/cfssl
chmod +x bin/cfssl

# Download cfssljson binaries
curl -L https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o bin/cfssljson
chmod +x bin/cfssljson

# Make certs directory to store certificates
mkdir -p certs

# Generate root CA certificate bundle (Public Certificate and Private Key)
cat > certs/etcd-root-ca-csr.json <<EOF
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
  "CN": "common-name"
}
EOF
cfssl gencert --initca=true certs/etcd-root-ca-csr.json | cfssljson --bare certs/etcd-root-ca

# cert-generation configuration (Used for client certificates)
cat > certs/etcd-gencert.json <<EOF
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
