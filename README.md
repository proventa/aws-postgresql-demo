# AWS PostgreSQL Demo

This repository hosts the concept of running a containerized and highly available PostgreSQL cluster with disaster recovery and monitoring on Fedora CoreOS. The CoreOS instances are provisioned with Ansible on AWS. The PostgreSQL cluster is managed by Patroni. The monitoring is done with Prometheus and Grafana.
## Table of Contents

- [Components used in this demo](#components-used-in-this-demo)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installing](#installing)
- [Usage](#usage)
  - [Provisioning the infrastructure](#provisioning)
- [Testing](#testing)
  - [Testing the etcd cluster](#testing-the-etcd-cluster)

## Components used in this demo

* [Spilo](https://github.com/zalando/spilo)
  * [Patroni](https://github.com/zalando/patroni)
* [etcd](https://github.com/coreos/etcd)
* [postgres_exporter](https://github.com/prometheus-community/postgres_exporter)
* [Prometheus](https://github.com/prometheus/prometheus)
* [Grafana](https://github.com/grafana/grafana)

![Architecture](docs/architecture.svg)

The above diagram shows the concept in a rather pragmatic manner: On the left is 3-member etcd HA-cluster. The middle consists of a 3-member PostgreSQL HA-cluster. And the right side shows one instance each with Prometheus and Grafana. AWS S3 object store is used for backups.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

<b>1. Make sure you have [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed on your local machine.</b>


You can check if Ansible is installed by running the following command:

```
ansible --version
```

If you haven't installed Ansible yet, please follow the [installation guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).

<b>2. Make sure you have [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) installed and configured with your credentials on your local machine.</b>

You can check if AWS CLI is installed by running the following command:

```
aws --version
```

If you haven't installed AWS CLI yet, please follow the [installation guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

### Installing

Clone the repository:

```
git clone https://gitlab.proventa.io/postgresql/fcos-postgresql-demo/aws-postgresql-demo.git
```

Change into the directory:

```
cd aws-postgresql-demo
```

## Usage

The infrastructure is provisioned with Ansible.

### Provisioning the infrastructure

The provisioning part creates the following resources:
- VPC
- Subnets
- Internet Gateway
- Route Tables
- Security Groups
- EC2 Instances (CoreOS)
- Key Pair

All of the above resources are tagged with the prefix `env` and the suffix `demo`.

The provisioning part can be executed with the following command:

```
ansible-playbook -i ansible/hosts start-ec2.yml
```

* To stop running EC2 instances, run:
```
ansible-playbook -i ansible/hosts stop-ec2.yml
```

For more detailed specification of the provisioned resources, please see the [start-ec2.yml](start-ec2.yml) Ansible playbook.

## Testing

### Testing the etcd cluster

First, SSH into one of the CoreOS instances as `etcd-user`:

```
ssh -i keys/etcd-user etcd-user@<instance-ip>
```

Then, we need to see the etcd cluster members. You can do that by running the following command:

```
podman exec -it etcd-container etcdctl --write-out=table member list
```

The output should look like this:

```
+------------------+---------+---------------------------+---------------------------+---------------------------+------------------+------------+
|        ID        | STATUS  |          NAME             |        PEER ADDRS         |       CLIENT ADDRS        | IS LEARNER       | RAFT TERM  |
+------------------+---------+---------------------------+---------------------------+---------------------------+------------------+------------+
|  1f0b3b2b3b3b3b3 | started | etcd-1f0b3b2b3b3b3b       | https://1.x.xx.xx:2380    | https://1.x.xx.xx:2379    | false            |          2 |
|  2f0b3b2b3b3b3b3 | started | etcd-2f0b3b2b3b3b3b       | https://2.x.xx.xx:2380    | https://2.x.xx.xx:2379    | false            |          2 |
|  3f0b3b2b3b3b3b3 | started | etcd-3f0b3b2b3b3b3b       | https://3.x.xx.xx:2380    | https://3.x.xx.xx:2379    | false            |          2 |
+------------------+---------+---------------------------+---------------------------+---------------------------+------------------+------------+
```

Then we will take the addresses in the `CLIENT ADDRS` column and test the cluster with the following command:

```
podman exec -it etcd-container etcdctl --write-out=table --cacert="/etc/certs/etcd-root-ca.pem" --insecure-skip-tls-verify --endpoints=https://1.x.xx.xx:2379,https://2.x.xx.xx:2379,https://3.x.xx.xx:2379 endpoint status
```

The output should look like this:

```
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+
|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+
| https://1.x.xx.xx:2379    |  1f0b3b2b3b3b3b3 |  3.5.9 |   20 kB |      true |      false |         2 |         10 |                 10 |
| https://2.x.xx.xx:2379    |  2f0b3b2b3b3b3b3 |  3.5.9 |   20 kB |     false |      false |         2 |         10 |                 10 |
| https://3.x.xx.xx:2379    |  3f0b3b2b3b3b3b3 |  3.5.9 |   20 kB |     false |      false |         2 |         10 |                 10 |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+
```

With that we can see that the etcd cluster is up and running.