# Provisioning AWS Resources with Ansible

In this section, we will learn how to provision AWS resources locally. We will use the [Ansible AWS Collection](https://docs.ansible.com/ansible/latest/collections/amazon/aws/index.html) to provision the AWS resources. We will create the following AWS resources:

- [VPC](https://aws.amazon.com/vpc/)
- [Subnet](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html)
- [Internet Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)
- [Route Table](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
- [Security Group](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [EC2 Key Pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
- [EC2 Instance](https://aws.amazon.com/ec2/)

## Prerequisites

In order to provision AWS resources, we need to have an AWS account. If you don't have an AWS account, please visit the official [AWS website](https://aws.amazon.com/) and create an account.

If you are also using Ubuntu WSL just like I am, there are some packages we need to install. So, before we can install the AWS CLI, we need to be able to extract or unzip the downloaded file. So, let's install the unzip package. To install the unzip package, run the following command:

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

Now that we have the AWS CLI installed, we need to configure it with our AWS account. To configure the AWS CLI, run the following command:

```bash
aws configure
```
There you will be prompted to enter the AWS Access Key ID, AWS Secret Access Key, default region name, and default output format. You can get the AWS Access Key ID and AWS Secret Access Key from the AWS account. You can set the default region name to the region where you want to provision the AWS resources. You can set the default output format to json.

After configuring the AWS CLI, we need to install the Ansible on our machine. We can install Ansible on Ubuntu by running the following command:

```bash
sudo apt install ansible
```

Ansible is using Python3 to run its tasks. So, keep in mind that Python3 will be installed as well.

We can verify the installation by running the following command:

```bash
ansible --version
```

The amazon.aws collection is already included in Ansible 2.9. So, we don't need to install it separately. We can verify that by running the following command:

```bash
ansible-galaxy collection list | grep amazon.aws
```

## Provisioning AWS Resources

Now that we have our prerequisites in place, we can dive into the process of provisioning AWS resources using Ansible and the AWS Collection.

### Writing Ansible Playbooks
Ansible playbooks are at the heart of automation with Ansible. They allow you to define the desired state of your infrastructure and use Ansible's declarative language to describe what should be done. In our case, we'll create a playbook to provision the AWS resources we mentioned earlier.

Create a new file, let's call it provision-network.yml, and let's start by specifying the basic structure of an Ansible playbook:

```yaml
---
- name: Provision AWS Network Resources
  hosts: localhost
  connection: local
  gather_facts: false
```
In this playbook, we've named it "Provision AWS Resources," specified that we're targeting the localhost as the host, and turned off fact gathering since we won't need it for this example. We are using the localhost as the host because Ansible will use the AWS CLI we have installed and configured earlier.

### Creating the VPC
Let's begin by creating the Virtual Private Cloud (VPC):

```yaml
---
  tasks:
    - name: Create VPC
    amazon.aws.ec2_vpc_net:
        name: postgres_demo_vpc
        cidr_block: 10.0.0.0/16
        region: eu-central-1
        tags:
        env: demo
        state: present
    register: vpc_net
```
In this task, we are using the ec2_vpc_net module to create a VPC. We are specifying the name of the VPC, the CIDR block, the region, and the tags. We are also registering the output of the task in the vpc_net variable. So we can take the VPC ID from the vpc_net variable and use it in the next task.

### Creating the Subnet
Now, let's add the task to create a subnet:

```yaml
    - name: Create Subnet
    amazon.aws.ec2_vpc_subnet:
        state: present
        vpc_id: "{{ vpc_net.vpc.id }}"
        cidr: 10.10.0.0/16
        map_public: true
        tags:
            Name: etcd-subnet
            env: demo
    register: etcd_subnet
```
In this task, we are using the ec2_vpc_subnet module to create a subnet. We are specifying the VPC ID, the CIDR block, and the tags. We are also registering the output of the task in the etcd_subnet variable. So we can take the Subnet ID from the etcd_subnet variable and use it in the next task.

### Creating the Internet Gateway
Next, let's add the task to create an internet gateway, so that the EC2 instance can access and be accessed from the internet:

```yaml
    - name: Create Internet Gateway
    amazon.aws.ec2_vpc_igw:
        vpc_id: "{{ vpc_net.vpc.id }}"
        state: present
        tags:
            env: demo
    register: etcd_igw
```
In this task, we are using the ec2_vpc_igw module to create an internet gateway. We are specifying the VPC ID and the tags. We are also registering the output of the task in the etcd_igw variable. So we can take the Internet Gateway ID from the etcd_igw variable and use it in the next task.


### Creating the Route Table
Now, let's add the task to create a route table:

```yaml
    - name: Create Route Table
    amazon.aws.ec2_vpc_route_table:
        vpc_id: "{{ vpc_net.vpc.id }}"
        tags:
            env: demo
        subnets:
        - "{{ etcd_subnet.subnet.id }}"
        routes:
        - dest: 0.0.0.0/0
            gateway_id: "{{ igw.gateway_id }}"
        - dest: ::/0
            gateway_id: "{{ igw.gateway_id }}"
```
In this task, we are using the ec2_vpc_route_table module to create a route table. We are specifying the VPC ID, the tags, the subnet ID, and the internet gateway ID so that the route table is associated with the internet gateway.

### Creating the Security Group
Next, let's add the task to create a security group:

```yaml
    - name: Create Security Group
    amazon.aws.ec2_group:
        name: etcd-sg
        description: Security Group for etcd
        vpc_id: "{{ vpc_net.vpc.id }}"
        region: eu-central-1
        rules:
            - proto: tcp
            ports:
                - 2379 # etcd client port
                - 2380 # etcd server port
            cidr_ip: 10.0.0.0/16
            - proto: tcp
            ports:
                - 22 # ssh port
            cidr_ip: 0.0.0.0/0
        tags:
            env: demo
        state: present
    register: etcd_sg
```
In this task, we are using the ec2_group module to create a security group. We are specifying the name of the security group, the description, the VPC ID, the region, the rules, and the tags. We are allowing the etcd client port (2379) and the etcd server port (2380) from the CIDR block of the VPC so that the etcd cluster can communicate with each other. We are also allowing the ssh port (22) from any IP address so that we can ssh into the EC2 instance. The output of the task is registered in the etcd_sg variable. So we can take the Security Group ID from the etcd_sg variable and use it in the next task.

### Creating the EC2 Key Pair
Now, let's add the task to create an EC2 key pair:

```yaml
    - name: Create key pair
    amazon.aws.ec2_key:
        name: etcd
        key_material: "{{ lookup('file', 'core.pub') }}"
        tags:
        env: demo
    register: key_pair
```
We are using the ec2_key module to create an EC2 key pair. We are specifying the name of the key pair, the public key, and the tags. Keep in mind that we have to create a key pair locally (e.g. with ssh-keygen) and then use the public key in the key_material parameter. The output of the task is registered in the key_pair variable. So we can take the Key Pair ID from the key_pair variable and use it in the next task.

### Launching the EC2 Instance
Finally, let's add the task to create an EC2 instance:

```yaml
    - name: Create EC2 instances
      amazon.aws.ec2_instance:
        state: running
        instance_type: t2.micro
        image_id: ami-01616b3a6ec881521 # Fedora CoreOS
        count: 3
        region: eu-central-1
        network:
          assign_public_ip: true
        security_group: "{{ etcd_sg.group_name }}"
        vpc_subnet_id: "{{ etcd_subnet.subnet.id }}"
        key_name: "{{ key_pair.key.name }}"
        tags: 
          env: demo
```
In this task, we are using the ec2_instance module to create an EC2 instance. We are specifying the instance type, the image ID, the count, the region, the network, the security group, the subnet ID, the key pair name, and the tags.

## Wrapping Up

Congratulations! You've now learned how to provision various AWS resources using Ansible and the AWS Collection. With this playbook as a starting point, you can extend and customize it to fit your specific use case. Automation through Ansible enables you to easily replicate your infrastructure while maintaining consistency and reliability.

In this blog post, we've covered the basics of provisioning AWS resources using Ansible and the AWS Collection. We discussed the prerequisites, wrote Ansible tasks to create VPCs, subnets, internet gateways, route tables, security groups, EC2 key pairs, and launched EC2 instances. By combining the power of Ansible's automation with AWS's robust infrastructure, you're now well-equipped to manage and deploy resources efficiently in the cloud.

Stay tuned for the next blog post in this series, where we'll dive into how to deploy an etcd cluster on AWS using Ansible!
