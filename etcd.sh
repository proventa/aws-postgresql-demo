#!/bin/bash

private_ipv4=$(hostname -I | awk '{print $1}')

# If private_ipv4 is empty, ask again until it is not empty. If already 60 seconds, exit.
count=0
while [ -z "$private_ipv4" ]; do
  sleep 1
  private_ipv4=$(hostname -I | awk '{print $1}')
  count=$((count+1))
  if [ $count -eq 60 ]; then
    echo "Private IPv4 is empty. Check your network."
    exit 1
  fi
done

mkdir -p /tmp/etcd/data

# to write service file for etcd with Docker
cat > /tmp/etcd.service <<EOF
[Unit]
Description=etcd with Docker
Documentation=https://github.com/coreos/etcd

[Service]
Restart=always
RestartSec=5s
TimeoutStartSec=0
LimitNOFILE=40000

ExecStart=/usr/bin/docker \
  run \
  --rm \
  --net=host \
  --name etcd-container \
  --volume=/tmp/etcd/data:/etcd-data \
  --volume=${HOME}/certs:/etcd-ssl-certs-dir \
  gcr.io/etcd-development/etcd:v3.3.8 \
  /usr/local/bin/etcd \
  --name etcd-$private_ipv4 \
  --data-dir /etcd-data \
  --listen-client-urls http://$private_ipv4:2379 \
  --advertise-client-urls http://$private_ipv4:2379 \
  --listen-peer-urls http://$private_ipv4:2380 \
  --initial-advertise-peer-urls http://$private_ipv4:2380 \
  --initial-cluster-token tkn \
  --initial-cluster-state new \
  --client-cert-auth \
  --trusted-ca-file /etcd-ssl-certs-dir/etcd-root-ca.pem \
  --cert-file /etcd-ssl-certs-dir/etcd-client.pem \
  --key-file /etcd-ssl-certs-dir/etcd.pem \
  --peer-client-cert-auth \
  --peer-trusted-ca-file /etcd-ssl-certs-dir/etcd-root-ca.pem \
  --peer-cert-file /etcd-ssl-certs-dir/etcd-client.pem \
  --peer-key-file /etcd-ssl-certs-dir/etcd.pem

ExecStop=/usr/bin/docker stop etcd-container

[Install]
WantedBy=multi-user.target
EOF

mv /tmp/etcd.service /etc/systemd/system/etcd.service

systemctl daemon-reload

systemctl enable etcd.service

systemctl start etcd.service