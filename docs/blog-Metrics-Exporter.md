# Exporting metrics from etcd, PostgreSQL, PgBouncer and Patroni

![metrics exporter](metrics-exporter.jpg)

In today's complex IT landscapes, monitoring is not just a nice-to-have but a necessity. It is important to know what is going on in your systems, and to be able to react quickly to any issues that arise. In this blog post, we will look at how to export metrics from etcd, PostgreSQL, PgBouncer and Patroni, and how to visualize them using Prometheus and Grafana.

## Prerequisites

Before we proceed, it's important to note that this blog post assumes that you have already gone through the previous blog post titled [Setting up a Connection Pooler for PostgreSQL on EC2 Instances](./blog-ConnectionPooler.md). In this current blog post, we will rely on the etcd cluster, and the Postgres cluster along with the PgBouncer created there, to export metrics from.

## Exporting metrics from etcd

etcd already has a built-in metrics exporter. This will expose the metrics on port `2379` by default. To verify that the metrics are being exported, you can SSH into one of the etcd nodes and run the following command:


```bash
curl http://localhost:2379/metrics
```

You should see a response similar to the following:

```bash
# HELP promhttp_metric_handler_requests_in_flight Current number of scrapes being served.
# TYPE promhttp_metric_handler_requests_in_flight gauge
promhttp_metric_handler_requests_in_flight 1

# HELP promhttp_metric_handler_requests_total Total number of scrapes by HTTP status code.
# TYPE promhttp_metric_handler_requests_total counter
promhttp_metric_handler_requests_total{code="200"} 21494
promhttp_metric_handler_requests_total{code="500"} 0
promhttp_metric_handler_requests_total{code="503"} 0

... # More metrics
```

If you see the above response, then your etcd cluster is ready to be scraped by Prometheus. So let's move on to the next step.

## Exporting metrics from PostgreSQL

Since PostgreSQL does not have a built-in metrics exporter, we will need to use a service called [pg_exporter](https://github.com/prometheus-community/postgres_exporter). This is a community-driven project that provides a metrics exporter for PostgreSQL. It comes in a container image, which makes it easy to deploy. We will run the container in the same VM as the PostgreSQL cluster, and expose the metrics on port `9187`. Here is the systemd butane configuration for the pg_exporter:

```yaml
- name: pg-exporter.service
  enabled: true
  contents: |
    [Unit]
    Description=Postgres Exporter with Podman

    After=patroni.service

    [Service]
    User=patroni-user
    Restart=always
    RestartSec=5s
    TimeoutStartSec=0
    LimitNOFILE=40000

    ExecStartPre=/usr/bin/podman rm -f pg-exporter-container
    ExecStart=/usr/bin/podman run \
      --rm \
      --name pg-exporter-container \
      --net=host \
      --volume=/etc/ssl/self-certs:/etc/ssl/self-certs \
      --volume=/usr/local/share/web-config.yml:/etc/web-config.yml \
      --env DATA_SOURCE_URI="localhost:5432" \
      --env DATA_SOURCE_USER="postgres" \
      --env DATA_SOURCE_PASS="zalando" \
      quay.io/prometheuscommunity/postgres-exporter \
        --web.config.file=/etc/web-config.yml \
        --collector.process_idle \
        --collector.postmaster

    ExecStop=/usr/bin/podman rm -f pg-exporter-container

    [Install]
    WantedBy=multi-user.target
```

Whereas the `web-config.yml` file in the `storage.files` section of the same butane configuration is as follows:

```yaml
- path: /usr/local/share/web-config.yml
  mode: 0644
  contents:
    inline: |
      tls_server_config:
        cert_file: /etc/ssl/self-certs/proventa-client-cert.pem
        key_file: /etc/ssl/self-certs/proventa-client-cert-key.pem
        client_auth_type: "RequireAndVerifyClientCert"
        client_ca_file: /etc/ssl/self-certs/proventa-root-ca.pem
```

The above configuration will run the pg_exporter container, and expose the metrics on port `9187`. It will also use the self-signed certificates that we generated with a script mentioned in the previous blog posts. Therefore, the metrics will be secured with TLS.

Other than that, we also specify the `DATA_SOURCE_URI`, `DATA_SOURCE_USER` and `DATA_SOURCE_PASS` environment variables. These are the credentials that the pg_exporter will use to connect to the PostgreSQL cluster. The `DATA_SOURCE_URI` is the URI of the PostgreSQL cluster. In our case, we will be using the URI `localhost:5432` since we will be running the pg_exporter container in the same VM as the PostgreSQL cluster. The `DATA_SOURCE_USER` and `DATA_SOURCE_PASS` are the credentials of the PostgreSQL cluster. In our case, we will be using the credentials `postgres` and `zalando` respectively.

Now that we have the systemd butane configuration for the pg_exporter, we can run deploy it by running the Ansible playbook script. Once the playbook script has finished running, the pg_exporter container will be running in the same VM as the PostgreSQL cluster, and exposing the metrics on port `9187`.

### Verifying the postgres_exporter service

To verify that the metrics are being exported, you can SSH into one of the PostgreSQL nodes and run the following command:

```bash
curl https://localhost:9187/metrics --cert /etc/ssl/self-certs/proventa-client-cert.pem --key /etc/ssl/self-certs/proventa-client-cert-key.pem
```

You should see a response similar to the following:

```bash
# HELP pg_stat_activity_count Number of rows in pg_stat_activity
# TYPE pg_stat_activity_count gauge
pg_stat_activity_count 1

# HELP pg_stat_activity_maxwritten_time Time of latest WAL flush in microseconds
# TYPE pg_stat_activity_maxwritten_time gauge
pg_stat_activity_maxwritten_time 1.6200000000000001e+15

... # More metrics
```

If you see the above response, then your PostgreSQL cluster is ready to be scraped by Prometheus. So let's move on to the next step.

## Exporting metrics from PgBouncer

Since PgBouncer does not have a built-in metrics exporter, we will need to use a service called [pgbouncer_exporter](https://github.com/prometheus-community/pgbouncer_exporter). Similar to the pg_exporter, it also comes in a container image, which makes it very easy to deploy. We will run the container in the same VM as the PgBouncer, and expose the metrics on port `9127`. Here is the systemd butane configuration for the pgbouncer_exporter:

```yaml
- name: pgbouncer-exporter.service
  enabled: true
  contents: |
    [Unit]
    Description=PgBouncer Exporter with Podman

    After=pgbouncer.service

    [Service]
    User=patroni-user
    Restart=always
    RestartSec=5s
    TimeoutStartSec=0
    LimitNOFILE=40000

    ExecStartPre=/usr/bin/podman rm -f pgbouncer-exporter-container
    ExecStart=/usr/bin/podman run \
      --rm \
      --name pgbouncer-exporter-container \
      --net=host \
      --volume=/etc/ssl/self-certs:/etc/ssl/self-certs \
      --volume=/usr/local/share/web-config.yml:/etc/web-config.yml \
      docker.io/prometheuscommunity/pgbouncer-exporter \
        --web.config.file=/etc/web-config.yml \
        --pgBouncer.connectionString="postgresql://stats_collector:collector_stats@localhost:6432/pgbouncer"

    ExecStop=/usr/bin/podman rm -f pgbouncer-exporter-container

    [Install]
    WantedBy=multi-user.target
```

Whereas the `web-config.yml` file is the same as the one used for the pg_exporter. The above configuration will run the pgbouncer_exporter container, and expose the metrics on port `9127`. The metrics will also be secured with TLS just like the pg_exporter.

We also specify the `pgBouncer.connectionString` environment variable. This is the connection string that the pgbouncer_exporter will use to connect to the PgBouncer cluster. In our case, we will be using the connection string `postgresql://stats_collector:collector_stats@localhost:6432/pgbouncer`.

After adding the systemd unit file to the butane configuration file that we created on the previous blog, we can run deploy it by running the Ansible playbook script. The pgbouncer_exporter container will be running in the same VM as the PgBouncer, and exposing the metrics on port `9127`.

### Verifying the pgbouncer_exporter service

To verify that the metrics are being exported, you can SSH into one of the PgBouncer nodes and run the following command:

```bash
curl https://localhost:9127/metrics --cert /etc/ssl/self-certs/proventa-client-cert.pem --key /etc/ssl/self-certs/proventa-client-cert-key.pem
```

You should see a response similar to the following:

```bash
# HELP promhttp_metric_handler_requests_total Total number of scrapes by HTTP status code.
# TYPE promhttp_metric_handler_requests_total counter
promhttp_metric_handler_requests_total{code="200"} 21993
promhttp_metric_handler_requests_total{code="500"} 0
promhttp_metric_handler_requests_total{code="503"} 0

... # More metrics
```

If you see the above response, then your PgBouncer cluster is ready to be scraped by Prometheus. So let's move on to the last step, that is, metrics from Patroni.

## Exporting metrics from Patroni

Patroni comes with a built-in metrics exporter. Therefore we don't need to use any third-party tools to export metrics from Patroni. The metrics are exposed on port `8008` by default. To verify that the metrics are being exported, you can SSH into one of the Patroni nodes and run the following command:

```bash
curl https://localhost:8008/metrics
```

You should see a response similar to the following:

```bash
# HELP patroni_version Patroni semver without periods.
# TYPE patroni_version gauge
patroni_version{scope="superman"} 030001

... # More metrics
```

If you see the above response, then your Patroni cluster is ready to be scraped by Prometheus.

## Wrapping up

In this blog post, we looked at how to export metrics from etcd, PostgreSQL, PgBouncer and Patroni. Now that the endpoints are ready to be scraped by Prometheus, we can move on to the next blog post where we will look at how to set up Prometheus and Grafana to visualize the metrics. So, stay tuned!