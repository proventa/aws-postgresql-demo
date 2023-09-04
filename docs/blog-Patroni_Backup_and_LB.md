# Leveraging Network Load Balancer and S3 Bucket for a Highly Available PostgreSQL Cluster

![Patroni Load Balancing and S3 Backup](patroni-loadbalancing-s3.svg)

In our previous blog post, we embarked on a journey to set up a highly available PostgreSQL cluster managed by Patroni using the Spilo image. We saw how Patroni, in collaboration with an etcd cluster, elevates PostgreSQL to new heights of availability and failover automation. Building upon that, let's explore the next chapter in our journey: leveraging a network load balancer and an S3 bucket for a highly available PostgreSQL cluster.

## Why Load Balancing?

![Why Load Balancing?](why-lb.svg)

In a highly available PostgreSQL cluster, load balancing is a must-have feature. There are many ways on how we can take advantage of the load balancer.

One option is to distribute the traffic across the cluster nodes. The load balancer can be configured so that it distributes read traffic across all the nodes in the cluster and write traffic to the primary node. However, in our case, we will be using the replicas as stand by replicas not active replicas. This means that the replicas will not be used for any incoming requests, but rather as a failover node in case the primary node goes down. 

So, the other option is to use the load balancer to determine the master node, to which the incoming requests can be routed. If the master node fails, the load balancer can <b>automatically</b> decide which node is the new master and route the requests to that node. This is the approach we will be using.

## Why S3 bucket?

In a highly available PostgreSQL cluster, it is important to have a backup of the database. The backup can be used to restore the database in case of a disaster. The backup can also be used to create new replicas, instead of streaming the data directly from the primary node. This is useful when the primary node is under heavy load and we want to create a new replica without affecting the performance of the primary node.

The backup can be stored in a file system or in an S3 bucket. The advantage of using an S3 bucket is that it is highly available and durable. According to the [AWS documentation](https://aws.amazon.com/s3/storage-classes/?nc1=h_ls), the standard S3 bucket is designed to deliver 99.999999999% durability and 99.99% availability of objects over a given year. This means that the S3 bucket is highly available and durable. It is also easy to set up and configure, since Spilo provides a way to automatically create WAL-E / WAL-G backups and store them in an S3 bucket. We will be using this feature to store the backups in an S3 bucket.

## Setting up the Load Balancer

Now let's see how we can set up a load balancer for our PostgreSQL cluster. We will be using the [AWS Network Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) for this purpose.

The first step is to create a new Target Group. The Target Group is a group of instances that will receive traffic from the load balancer. In our case, the Target Group will contain the instances of our PostgreSQL cluster. We will create a new Target Group called `patroni-tg` and add the instances of our PostgreSQL cluster to it. We can use the following Ansible task to create the Target Group:

```
- name: Create target list
    set_fact:
    target_list: "{{ target_list | default([]) + [{'Id': item, 'Port': 5432}] }}"
    loop: "{{ ec2_instance.instance_ids }}" # The list of instance ids that will receive traffic from the load balancer

- name: Ensure Target Group for Patroni cluster exist
    community.aws.elb_target_group:
    name: patroni-tg
    region: "{{ instance_region }}"
    vpc_id: "{{ vpc_net.vpc.id }}"
    protocol: tcp
    port: 5432
    health_check_protocol: http
    health_check_path: /
    health_check_port: 8008
    successful_response_codes: "200" # Only forward the traffic to the master node
    target_type: instance
    targets: "{{ target_list }}" # The list of instance ids that will receive traffic from the load balancer
    state: present
    register: tg
```

In the `health_check_port ` parameter, we specify the port on which the health check will be performed. In our case, we will be using the health check endpoint provided by Patroni. The health check endpoint is available on port 8008. The `successful_response_codes` parameter specifies the response codes that are considered successful. In our case, we will only forward the traffic to the master node, so we will only consider the response code 200 as successful. The replica nodes will return the response code 503, which means that the node is not available to receive traffic.

The next step is to create a new Load Balancer. We will create a new Load Balancer called `patroni-nlb` and add the Target Group `patroni-tg` to it. We can use the following Ansible task to create the Load Balancer:

```
- name: Ensure Network Load Balancer for Patroni cluster exist
community.aws.elb_network_lb:
    name: patroni-nlb
    subnets:
    - "{{ patroni_subnet.subnet.id }}"
    state: present
    listeners:
    - Protocol: TCP
        Port: 5432
        DefaultActions:
        - Type: forward
            TargetGroupArn: "{{ tg.target_group_arn  }}"
```

In the `subnets` parameter, we specify the subnets in which the load balancer will be created. In our case, we will be using the subnet in which our PostgreSQL cluster is running. In the `listeners` parameter, we specify the port on which the load balancer will listen for incoming requests. In our case, we will be using port 5432, which is the default port for PostgreSQL. We also specify the Target Group that will receive the incoming requests. In our case, we will be using the Target Group `patroni-tg` that we created in the previous step.

The load balancer will be assigned with a DNS name. Since, we are assigning the load balancer in a public subnet, the DNS name will be publicly accessible. We can use the DNS name to connect to the PostgreSQL cluster. To get the DNS name of the load balancer, we can navigate to the AWS console and select the load balancer or we can use the following command on your terminal:

```
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



## Setting up the S3 Bucket

Now let's see how we can set up an S3 bucket for our PostgreSQL cluster. We will be using the [AWS S3 Bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) for this purpose.

The first step is to create a new S3 Bucket. We will create a new S3 Bucket called `patroni-demo-bucket`. We can use the following Ansible task to create the S3 Bucket:

```
- name: Ensure that a S3 Bucket for WAL backups exists
    amazon.aws.s3_bucket:
    name: "patroni-demo-bucket
    state: present
    region: "{{ instance_region }}"
    tags:
        Name: patroni-demo-bucket
        env: demo
    register: s3_bucket
```

The next step is to create a new IAM Role that will be used by the EC2 instances running the Spilo image to access the S3 bucket. The IAM Role should have specific permissions to access the S3 bucket. We can use the following Ansible task to create the IAM Role and its permissions:

```
- name: Create IAM Role for Patroni WAL
    community.aws.iam_role:
    name: PatroniWALRole
    state: present
    region: "{{ instance_region }}"
    assume_role_policy_document: "{{ lookup('file', './assume_role_policy.json')|string }}"
    tags:
        Name: PatroniWALRole
        env: demo
    register: iam_role

- name: Save the IAM Role ARN to a file
    ansible.builtin.shell: echo "\nAWS_ROLE_ARN={{ iam_role.arn }}" >> ../tmp/patroni-env # Will be used by Spilo

- name: Create instance profile for Patroni WAL
    amazon.aws.iam_instance_profile:
    name: PatroniWALInstanceProfile
    state: present
    region: "{{ instance_region }}"
    role: "{{ iam_role.role_name }}"
    tags:
        Name: PatroniWALInstanceProfile
        env: demo
    register: iam_instance_profile

- name: Attach S3 Policy to Patroni WAL Role
    amazon.aws.iam_policy:
    policy_name: PatroniWALPolicy
    iam_type: role
    iam_name: "{{ iam_role.role_name }}"
    state: present
    region: "{{ instance_region }}"
    policy_json : "{{ lookup('file', './patroni-wal-role-policy.json')|string }}"
```

Notice that we are using the `assume_role_policy_document` parameter to specify on which resources the IAM Role can be assumed. In our case, we will be using the EC2 instances running the Spilo image. We are also using the `policy_json` parameter to specify the permissions that the IAM Role will have. In our case, we will be using the permissions provided by the `patroni-wal-role-policy.json` file. The permissions in the file are the minimum permissions required to access the S3 bucket. To get the details about the permissions, you can refer to our [Github repository](https://github.com/proventa/aws-postgresql-demo).

## Putting the S3 Bucket and Spilo Together

Now, let's see how we can put the S3 bucket and Spilo together. We can take the systemd unit file from the [previous blog post](https://www.proventa.io/blog/Patroni-PostgreSQL-High-Availability) and modify it to include the S3 bucket. The modified systemd unit file should look like this:

```
... # Omitted for brevity
ExecStart=/usr/bin/podman \
    run \
    --rm \
    --net=host \
    --name patroni-container \
    --volume /etc/ssl/etcd-certs:/etc/ssl/etcd-certs \
    --volume ${HOME}/patroni:/home/postgres/pgdata \
    --env SCOPE=superman \
    --env PGVERSION=15 \
    --env ETCD3_PROTOCOL="https" \
    --env ETCD3_HOSTS="${ETCD_HOSTS}" \
    --env ETCD3_CACERT="/etc/ssl/etcd-certs/proventa-etcd-root-ca.pem" \
    --env ETCD3_CERT="/etc/ssl/etcd-certs/proventa-etcd-client-cert.pem" \
    --env ETCD3_KEY="/etc/ssl/etcd-certs/proventa-etcd-client-cert-key.pem" \
    --env AWS_REGION="eu-central-1" \ # The region in which the S3 bucket is located
    --env WAL_S3_BUCKET="patroni-demo-bucket" \ # The name of the S3 bucket
    --env AWS_ROLE_ARN="${AWS_ROLE_ARN}" \ # The ARN of the IAM Role
    --env USE_WALG_BACKUP="true" \ # Enable WAL-G backups
    --env USE_WALG_RESTORE="true" \ # Enable WAL-G restore
    ghcr.io/zalando/spilo-15:3.0-p1

... # Omitted for brevity
```

We are specifying the AWS_REGION, WAL_S3_BUCKET and AWS_ROLE_ARN environment variables. The AWS_REGION environment variable specifies the region in which the S3 bucket is located. The WAL_S3_BUCKET environment variable specifies the name of the S3 bucket. The AWS_ROLE_ARN environment variable specifies the ARN of the IAM Role. The IAM Role will be used by the EC2 instances running the Spilo image to access the S3 bucket.

Now, let's check if the backups are being stored in the S3 bucket. We can do so by navigating to the AWS console and selecting the `patroni-demo-bucket` S3 bucket. We should see a new folder called `spilo` in the S3 bucket. The folder should contain a folder with the name of your Patroni cluster and inside that folder, we should see the WAL-G backups. We can also check if the backups are being stored in the S3 bucket by running the following command on your terminal:

```
aws s3 ls s3://patroni-demo-bucket/spilo/superman --recursive --human-readable --summarize
```

The output should look like this:

```
2023-09-01 09:08:08  192 Bytes spilo/superman/wal/15/wal_005/000000010000000000000002.00000060.backup.br
2023-09-01 09:08:07    2.9 KiB spilo/superman/wal/15/wal_005/000000010000000000000002.br
...
```

With that we can see that the backups are being stored in the S3 bucket.

## Wrapping Up

There you have it! We have seen how we can leverage a network load balancer and an S3 bucket for a highly available PostgreSQL cluster. By using the Network Load Balancer and Amazon S3 Bucket, we've made our PostgreSQL cluster more robust and safer. With the Load Balancer, our system can efficiently handle traffic even if one node fails, keeping things running smoothly. Plus, the S3 bucket gives us a secure place to store our data backups, so we're ready for any surprises that come our way.  Thanks for reading! We hope you found this blog post helpful!