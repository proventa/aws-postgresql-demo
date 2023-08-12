mkdir -p bin && rm -f bin/cfssl* && rm -rf certs && mkdir -p certs

curl -L https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o bin/cfssl
chmod +x bin/cfssl

curl -L https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o bin/cfssljson
chmod +x bin/cfssljson

mkdir -p certs

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

# cert-generation configuration
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
