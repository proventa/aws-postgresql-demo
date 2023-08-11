#!/bin/bash

private_ipv4=$(hostname -I | awk '{print $1}')

mkdir -p /tmp/etcd/data

setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config


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
  --name etcd-v3.3.8 \
  --volume=/tmp/etcd/data:/etcd-data \
  gcr.io/etcd-development/etcd:v3.3.8 \
  /usr/local/bin/etcd \
  --name etcd-$private_ipv4 \
  --data-dir /etcd-data \
  --listen-client-urls http://$private_ipv4:2379 \
  --advertise-client-urls http://$private_ipv4:2379 \
  --listen-peer-urls http://$private_ipv4:2380 \
  --initial-advertise-peer-urls http://$private_ipv4:2380 \
  --initial-cluster-token tkn \
  --initial-cluster-state new

ExecStop=/usr/bin/docker stop etcd-v3.3.8

[Install]
WantedBy=multi-user.target
EOF

mv /tmp/etcd.service /etc/systemd/system/etcd.service

systemctl daemon-reload

systemctl enable etcd.service

systemctl start etcd.service