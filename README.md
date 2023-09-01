# AWS PostgreSQL Demo

This repository hosts the concept of running a containerized and highly available PostgreSQL cluster with disaster recovery and monitoring on Fedora CoreOS. The CoreOS instances are provisioned with Ansible on AWS. The PostgreSQL cluster is managed by Patroni. The monitoring is done with Prometheus and Grafana.
## Table of Contents

- [AWS PostgreSQL Demo](#aws-postgresql-demo)
  - [Table of Contents](#table-of-contents)
  - [Components used in this demo](#components-used-in-this-demo)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installing](#installing)
  - [Usage](#usage)
    - [Provisioning the infrastructure](#provisioning-the-infrastructure)
  - [Verifying](#verifying)
    - [Verifying the etcd cluster](#verifying-the-etcd-cluster)
    - [Verifying the PostgreSQL cluster](#verifying-the-postgresql-cluster)
    - [Connecting to the PostgreSQL cluster](#connecting-to-the-postgresql-cluster)
    - [Verifying the WAL-G backups in S3 bucket](#verifying-the-wal-g-backups-in-s3-bucket)

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

```bash
ansible --version
```

If you haven't installed Ansible yet, please follow the [installation guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).

<b>2. Make sure you have [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) installed and configured with your credentials on your local machine.</b>

You can check if AWS CLI is installed by running the following command:

```bash
aws --version
```

If you haven't installed AWS CLI yet, please follow the [installation guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

### Installing

Clone the repository:

```bash
git clone https://gitlab.proventa.io/postgresql/fcos-postgresql-demo/aws-postgresql-demo.git
```

Change into the directory:

```bash
cd aws-postgresql-demo
```

## Usage

The infrastructure is provisioned with Ansible.

### Provisioning the infrastructure

The following resources will be provisioned on AWS:
- VPC
- Subnets
- Internet Gateway
- Route Tables
- Security Groups
- EC2 Instances (Fedora CoreOS)
- Key Pairs
- IAM Roles and its Policies and instance profiles
- S3 Bucket
- Network Load Balancer
- Target Groups

All of the resources that we are going to provision are tagged with the prefix `env` and the suffix `demo`.

* The provisioning of the etcd Cluster part can be executed with the following command:

```bash
ansible-playbook cluster-etcd/init-etcd-cluster.yml
```

* and the provisioning of the PostgreSQL Cluster with Patroni can be executed with the following command:

```bash
ansible-playbook cluster-patroni/init-patroni-cluster.yml
```

* To stop running the PostgreSQL Cluster or the etcd Cluster, navigate to the corresponding directory (`cluster-patroni` or `cluster-etcd`) and run the following command:

```bash
ansible-playbook terminate-<cluster-name>-cluster.yml
```
Replace `<cluster-name>` with `patroni` or `etcd`.

For more detailed specification of the provisioned resources, please see the navigate to the corresponding directory (`cluster-patroni` or `cluster-etcd`).

## Verifying

To verify the infrastructure, we need to SSH into the instances. We can do that by running the following command:

```bash
ssh -i keys/<cluster-name>-user <cluster-name>-user@<instance-ip>
```
Replace `<cluster-name>` with `patroni` or `etcd` and `<instance-ip>` with the IP address of the instance.


### Verifying the etcd cluster

We will take the client addresses of the etcd Cluster and save it into a variable called `ENDPOINTS`. We can do that by running the following command:

```bash
ENDPOINTS=$(podman exec etcd-container etcdctl member list | awk -F ', ' '{print $5}' | tr '\n' ',' | sed 's/.$//')
```

Then we can check the status and the health of the etcd cluster by running the following command:
```bash
podman exec -it etcd-container etcdctl --write-out=table --cacert="/etcd-certs/proventa-etcd-root-ca.pem"  --endpoints=$ENDPOINTS --cert="/etcd-certs/proventa-etcd-client-cert.pem" --key="/etcd-certs/proventa-etcd-client-cert-key.pem" endpoint status

podman exec -it etcd-container etcdctl --write-out=table --cacert="/etcd-certs/proventa-etcd-root-ca.pem"  --endpoints=$ENDPOINTS --cert="/etcd-certs/proventa-etcd-client-cert.pem" --key="/etcd-certs/proventa-etcd-client-cert-key.pem" endpoint health
```

The output should look like this:

```
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+-------+
|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERROR |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+-------+
| https://1.x.xx.xx:2379    |  1f0b3b2b3b3b3b3 |  3.5.9  |   20 kB |      true |      false |         2 |         10 |                 10 |       |
| https://2.x.xx.xx:2379    |  2f0b3b2b3b3b3b3 |  3.5.9  |   20 kB |     false |      false |         2 |         10 |                 10 |       |
| https://3.x.xx.xx:2379    |  3f0b3b2b3b3b3b3 |  3.5.9  |   20 kB |     false |      false |         2 |         10 |                 10 |       |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+-------+

+---------------------------+--------+------+-------+
|         ENDPOINT          | HEALTH | TOOK | ERROR |
+---------------------------+--------+------+-------+
| https://1.x.xx.xx:2379    |   true |  2ms |       |
| https://2.x.xx.xx:2379    |   true |  2ms |       |
| https://3.x.xx.xx:2379    |   true |  2ms |       |
+---------------------------+--------+------+-------+

```

With that we can see that the etcd cluster is up and running.

### Verifying the PostgreSQL cluster

Once you are connected to one of the EC2 instances of the PostgreSQL cluster, you can run the following command to check the status of the Spilo container:

```	
podman ps
```

If you can find a container running with the name `patroni-container`, then the Spilo container is running. Now, we can check the status of the Patroni cluster by running the following command:

```
podman exec -it patroni-container patronictl list
```

The output should be similar to the following:

```
+ Cluster: superman (101010101010101010) ---+----+-----------+
| Member | Host        | Role    | State    | TL | Lag in MB |
+--------+-------------+---------+----------+----+-----------+
| node1  | 1.x.x.x     | Leader  | running  |  1 |           |
| node2  | 2.x.x.x     | Replica | running  |  1 |         0 |
| node3  | 3.x.x.x     | Replica | running  |  1 |         0 |
+--------+-------------+---------+----------+----+-----------+
```

The output shows that we have a Patroni cluster with one master node and two replica nodes. The master node is running on node1 and the replica nodes are running on node2 and node3. The output also shows that the replication is working fine since the lag is 0.

### Connecting to the PostgreSQL cluster

To connect to the PostgreSQL cluster, we need to get the IP address of the Network Load Balancer. We can do that by running the following command:

```bash
aws elbv2 describe-load-balancers --names patroni-nlb --query 'LoadBalancers[*].DNSName' --output text
```

The output should look like this:

```
patroni-nlb-e81427453f1cdf1a.elb.eu-central-1.amazonaws.com
```

Now, we can connect to the PostgreSQL cluster using `postgres` as the username and `zalando` (default password) as the password by running the following command:

```bash
psql -h patroni-nlb-e81427453f1cdf1a.elb.eu-central-1.amazonaws.com -U postgres
```

And voila! We are connected to the PostgreSQL cluster.

### Verifying the WAL-G backups in S3 bucket

To verify the WAL-G backups in S3 bucket, we need to get the name of the S3 bucket. We can do that by running the following command:

```bash
aws s3api list-buckets --query 'Buckets[*].Name' --output text
```

The output should look like this:

```
patroni-demo-bucket
```

Now, we can check the WAL-G backups in the S3 bucket by running the following command:

```bash
aws s3 ls s3://patroni-demo-bucket/spilo/superman --recursive --human-readable --summarize
```

The output should look like this:

```
2023-09-01 09:08:09  130.5 KiB spilo/superman/wal/15/basebackups_005/base_000000010000000000000003/files_metadata.json
2023-09-01 09:08:09  376 Bytes spilo/superman/wal/15/basebackups_005/base_000000010000000000000003/metadata.json
2023-09-01 09:08:08  192 Bytes spilo/superman/wal/15/wal_005/000000010000000000000002.00000060.backup.br
2023-09-01 09:08:07    2.9 KiB spilo/superman/wal/15/wal_005/000000010000000000000002.br
```

The output shows that the WAL-G backups are working fine and the backups are being uploaded to the S3 bucket.

