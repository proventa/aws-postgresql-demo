#!/bin/bash

# If core and core.pub and etcd-user and etcd-user.pub exist, then skip this step
if [ -f keys/core ] && [ -f keys/core.pub ] && [ -f keys/etcd-user ] && [ -f keys/etcd-user.pub ]; then
  echo "Keys already exist. Skipping this step."
  exit 0
fi

# Create the keys directory if it doesn't exist
if [ ! -d keys ]; then
  mkdir keys
fi

# Generate the core key
ssh-keygen -t rsa -b 4096 -f keys/core -N '' -C core

# Generate the etcd-user key
ssh-keygen -t rsa -b 4096 -f keys/etcd-user -N '' -C etcd-user