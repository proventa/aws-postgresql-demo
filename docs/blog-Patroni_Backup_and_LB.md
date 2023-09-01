# Leveraging Network Load Balancer and S3 Bucket for a Highly Available PostgreSQL Cluster

![Patroni Load Balancing and S3 Backup](patroni-loadbalancing-s3.svg)

In our previous blog post, we embarked on a journey to set up a highly available PostgreSQL cluster managed by Patroni using the Spilo image. We saw how Patroni, in collaboration with an etcd cluster, elevates PostgreSQL to new heights of availability and failover automation. Building upon that, let's explore the next chapter in our journey: leveraging a network load balancer and an S3 bucket for a highly available PostgreSQL cluster.

## Why Load Balancing?

![Why Load Balancing?](why-lb.svg)

In a highly available PostgreSQL cluster, load balancing is a must-have feature. There are many ways on how we can take advantage of the load balancer.

One option is to distribute the traffic across the cluster nodes. The load balancer can be configured so that it distributes read traffic across all the nodes in the cluster and write traffic to the primary node. However, in our case, we will be using the replicas as stand by replicas not active replicas. This means that the replicas will not be used for any incoming requests, but rather as a failover node in case the primary node goes down. 

So, the other option is to use the load balancer to determine the master node, to which the incoming requests can be routed. If the master node fails, the load balancer can <b>automatically</b> decide which node is the new master and route the requests to that node. This is the approach we will be using.

## Why S3 bucket?


## Setting up the Load Balancer

## Setting up the S3 Bucket

## Putting the S3 Bucket and Spilo Together

## Wrapping Up
