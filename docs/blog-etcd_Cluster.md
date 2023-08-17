# Building a High-Availibity etcd Cluster on AWS

![etcd Architecture](etcd-architecture.svg)

Welcome to the journey of building a high-availibity distributed key-value store. In this project we will build an etcd cluster inside Podman containers on AWS EC2 Instances. etcd is an open source, distributed key-value store designed for securely managing configuration data in distributed systems. Using <b>Raft</b> consensus protocol, it ensures consistent data across multiple machines. etcd is one of the most essential components for configuring management, and leader election in building reliable and highly available applications.

## Prerequisites

If you haven't installed and configured Ansible and AWS CLI, please visit the [Provisioning AWS Resources with Ansible](blog-AWS_Ansible_Combo.md) page. There you will find the steps to install and configure Ansible and AWS CLI on your local machine.

## etcd on EC2 Instances

As the base image we will use <b>Fedora CoreOS</b>. Fedora CoreOS is an automatically updating, minimal, container-focused operating system. A big plus from Fedora CoreOS is that it comes with <b>Docker</b> and <b>Podman</b> installed. So, it is perfect for running containerized applications such as our etcd service which we will run inside a container. In Fedora CoreOS there is a file called <b>Ignition</b> file, which can be attached as the <i>user data</i> specification of our EC2 instances. This file is used to configure the instance during the boot process. However, the file is structured a little bit complex. Therefore, Fedora recommends to use <b>Butane</b> to generate the Ignition file. Butane is a more human-readable version Fedora CoreOS' Ignition file. The structure of the file is the same as a YAML file. So, it is easier to read and understand. Let's take a better look of how the Butane file is structured any what kind of configuration we can do with it.

```yaml
variant: fcos
version: 1.5.0
passwd:
  users:
    - name: etcd-user
      ssh_authorized_keys_local:
      - /path/to/public_key.pub
```

We can create one or more users under ```passwd``` and ```users```. In this case, we have created a user called etcd-user. We can also specify the public key of the user. The public key will be used to connect to the instance via SSH. The user is not associated with any other groups. So, it is a normal (or should I say rootless) user.

```yaml
storage:
  files:
    - path: /etc/certs/etcd-root-ca.crt
      mode: 0644
      local:
        path: /path/to/etcd-root-ca.crt
    - path: /etc/certs/etcd-root-ca-key.crt
      mode: 0644
      local:
        path: /path/to/etcd-root-ca-key.crt
```

We can also specify the files that we want to copy to the instance. In this case, we are copying the etcd root CA certificate and key to the instance. The files will be copied to the specified path inside the instance. We can also specify the file permissions using the ```mode``` attribute. The ```0644``` here means that the owner can read and write the file, while the group and others can only read the file.

```yaml
systemd:
  units:
    - name: etcd.service
      enabled: true
      contents: |
        [Unit]
        Description=etcd
        After=enable-linger.service setup-network-environment.service selinux-permissive.service
        Requires=enable-linger.service setup-network-environment.service selinux-permissive.service

        [Service]
        User=etcd-user
        EnvironmentFile=/etc/network-environment
        Restart=always
        RestartSec=5s
        TimeoutStartSec=0
        LimitNOFILE=40000

        ExecStartPre=/usr/bin/mkdir -p ${HOME}/etcd-data
        ExecStartPre=/usr/bin/podman rm -f etcd-container
        ExecStart=/usr/bin/podman \
          run \
          --rm \
          --net=host \
          --name etcd-container \
          --volume=${HOME}/etcd-data:/etcd-data \
          --volume=/etc/certs:/etc/certs \
          --volume=/etc/ssl/certs:/etc/ssl/certs \
          gcr.io/etcd-development/etcd:v3.5.9 \
          /usr/local/bin/etcd \
          --name etcd-${DEFAULT_IPV4} \
          --data-dir /etcd-data \
          --listen-client-urls https://${DEFAULT_IPV4}:2379,http://127.0.0.1:2379 \
          --advertise-client-urls https://${DEFAULT_IPV4}:2379 \
          --listen-peer-urls https://${DEFAULT_IPV4}:2380 \
          --initial-advertise-peer-urls https://${DEFAULT_IPV4}:2380 \
          --client-cert-auth \
          --auto-tls \
          --trusted-ca-file /etc/ssl/certs/etcd-root-ca.pem \
          --peer-client-cert-auth \
          --peer-auto-tls \
          --peer-trusted-ca-file /etc/ssl/certs/etcd-root-ca.pem \
          --discovery=${ETCD_DISCOVERY_ADDR}

        ExecStop=/usr/bin/podman rm -f etcd-container

        [Install]
        WantedBy=multi-user.target
```

The last part of the Butane file is the ```systemd``` section. Here we can specify the systemd units that we want to run inside the instance. In this case, we are running the etcd service. The ```name``` attribute is used to specify the name of the systemd unit. The ```enabled``` attribute is used to specify whether the unit should be enabled or not. The ```contents``` attribute is used to specify the content of the systemd unit. The content of the systemd unit is the same as the systemd unit file in the etcd repository. However, I have made some changes to the unit file. I have added some systemd units that will be run before the etcd service. We have a unit called <b>selinux-permissive.service</b> that runs a shell script for turning SELinux into permissive mode. The second unit is called <b>setup-network-environment.service</b>. It runs a script for setting up the network environment. The setup-network-environment.service was provided by Kelsey Hightower and the source code can be found [here](https://github.com/kelseyhightower/setup-network-environment). What it does, is, it creates a file called <b>network-environment</b> that contains the IP address of the EC2 instance that will be used for our etcd service. The third unit is called <b>enable-linger.service</b>. It runs a shell script for enabling the linger feature for the etcd-user. This is to avoid that files owned by the etcd-user are removed when the user logs out. The fourth unit is called <b>etcd.service</b> that runs the etcd service inside a podman container. Let's take a deeper look at the etcd.service.

Under ```[Service]``` we can see that ```User``` is set to etcd-user and ```EnvironmentFile``` is set to /etc/network-environment. It means that the service will be run as the etcd-user and the environment variables will be read from the /etc/network-environment file. The ```ExecStartPre``` will create a directory called etcd-data inside the home directory of the etcd-user. This is the directory which will be mounted to the /etcd-data directory inside the container, where the etcd data will be stored. The ```ExecStart``` will run the etcd service inside a podman container.

There are several flags used in ```ExecStart```, but I will mention some that could be interesting to know. The ```--auto-tls``` and ```--peer-auto-tls``` is used to enable TLS for the client and peer communication. The certificates will be automatically generated by etcd. The localhost address is also listed in the ```--listen-client-urls``` flag. It means that the etcd service will listen on port 2379 on the localhost. This will be useful if we are inside the EC2 instance and want to quickly check the status of the etcd service. The ```--discovery``` flag is used to specify the discovery URL. In this case, we are using the public discovery URL provided by etcd. It is an amazing feature provided by etcd to simplify the process of bootstrapping a new cluster. The etcd nodes can automatically join the cluster by using the discovery URL. Therefore we don't need to know the IP address of the other nodes in advance.

