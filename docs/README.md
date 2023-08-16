# Building a High-Availibity etcd Cluster on AWS

Welcome to the journey of building a high-availibity distributed key-value store. In this project we will use [etcd](https://etcd.io), which is a distributed key-value store that provides a reliable way to store data across multiple machines. It’s open-source and available on GitHub. etcd gracefully handles leader elections during network partitions and will tolerate machine failure, including the leader.

## Prerequisites

I am currently using Ubuntu WSL on Windows 10. So, before we start, let's make sure we have the following tools installed:

<b>1. AWS CLI</b> is a unified tool to manage your AWS services on the command line. With just one tool to download and configure, you can control multiple AWS services from the command line and automate them through scripts. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

Before we install the AWS CLI, we need to be able to extract or unzip the downloaded file. So, we need to install the unzip package. To install the unzip package, run the following command:

```bash
sudo apt install unzip
```

After that, we can download and install the AWS CLI. To download the AWS CLI, run the following command:

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```
And then, we can verify the installation by running the following command:

```bash
aws --version
```

<b>2. Ansible</b> is an open-source automation tool that empowers you to manage, configure and deploy your systems. It runs on many Unix-like system. [Install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)


We can install Ansible on Ubuntu by running the following command:

```bash
sudo apt install ansible
```

Ansible is using Python3 to run its tasks. So, keep in mind that Python3 will be installed as well.

We can verify the installation by running the following command:

```bash
ansible --version
```

## Provisioning the infrastructure

We made it! We have prepared all the tools we need to provision the infrastructure. Now, let's get started!

### Network and Security Components
Before we can provision EC2 instances where the etcd will be running, there are several network components that we need to provision first. The network components are:

<b>1. VPC</b> - A virtual network dedicated to your AWS account. It is logically isolated from other virtual networks in the AWS Cloud. [AWS VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)

<b>2. Subnet</b> - A range of IP addresses in your VPC where you can place groups of isolated resources. [AWS Subnet](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html)

<b>3. Internet Gateway</b> - A gateway that you attach to your VPC to enable communication between resources in your VPC and the internet. [AWS Internet Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)

<b>4. Route Table</b> - A set of rules, called routes, that are used to determine where network traffic is directed. [AWS Route Table](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)

<b>5. Security Group</b> - A security group acts as a virtual firewall for your instance to control inbound and outbound traffic. In this case we need to open port 22 on the TCP protocol to allow SSH connection to the EC2 instances and, for the sake of simplicity, we will allow all traffic within the subnet CIDR block so that each EC2 instances can communicate with each other. [AWS Security Group](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)

<b>6. Key Pair</b> is a secure login information for your EC2 instances.This will be needed to SSH into the EC2 instances. [AWS Key Pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)

To get familiar on how to provision the AWS resources locally, you can play around with the AWS CLI commands. However there is a better way to do it. We can use Ansible to provision the resources! There are many modules that we can use in Ansible. In the playbook, I have decided to use the <b>ec2_vpc_net</b> module to provision the VPC, <b>ec2_vpc_subnet</b> module to provision the subnet, <b>ec2_vpc_igw</b> module to provision the internet gateway, <b>ec2_vpc_route_table</b> module to provision the route table, <b>ec2_security_group</b> module to provision the security group, and <b>ec2_key</b> module to provision the key pair. You can find other modules [here](https://docs.ansible.com/ansible/latest/collections/amazon/aws/index.html).

### EC2 instances
Ansible also has a module called [ec2_instance](https://docs.ansible.com/ansible/latest/collections/amazon/aws/ec2_instance_module.html#ansible-collections-amazon-aws-ec2-instance-module) that can be used to provision the EC2 instances. Just like the AWS CLI, you can configure the specification of the EC2 instance you want to deploy. For example, the instance type, the AMI, the security group, etc.

In the playbook I have decided to use the <b>Fedora CoreOS</b> as the base image. Fedora CoreOS is an automatically updating, minimal, container-focused operating system. The reason for using this is because it is designed to be lightweight and secure. So, it is perfect for running containerized applications such as our etcd container. In Fedora CoreOS there is a file called <b>Ignition</b> file. This file is used to configure the instance during the boot process. However, the file is structured a little bit complex. Therefore, Fedora recommends to use <b>Butane</b> to generate the Ignition file. Butane is a tool for creating and modifying Fedora CoreOS Ignition configs. The structure of the file is the same as a YAML file. So, it is easier to read and understand. In the Butane file, we will configure the user, systemd unit, and some shell scripts.


