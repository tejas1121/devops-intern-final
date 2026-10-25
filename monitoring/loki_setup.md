# Loki setup notes

Log aggregation for the NGINX application using Grafana Loki 3.2.1, Promtail 3.2.1 and Grafana 11.3.0.

## How the stack was started

From the repository root (Docker Desktop 29.1.3, Compose v5):

```bash
docker compose -f monitoring/docker-compose.yaml up -d
# On my machine port 3000 was already in use, so I ran:
GRAFANA_PORT=3001 docker compose -f monitoring/docker-compose.yaml up -d
curl -s localhost:3100/ready          # -> ready
```

- `loki-config.yaml` is a single-binary Loki with filesystem storage (TSDB, schema v13) and 7-day retention.
- `promtail-config.yaml` discovers containers through `/var/run/docker.sock` (`docker_sd_configs`), so it picks up both the container started with `docker run` and the containers Nomad's docker driver creates.
- `grafana-datasources.yaml` provisions Loki as the default data source, so Explore works with no clicks.

## Label set

| Label | Source | Example |
|---|---|---|
| `job` | `docker` by default, overridden by the Nomad job name | `nginx-app` |
| `container` | Docker container name without the leading `/` | `nginx-ba05188a-...` |
| `service` | Compose service name, or the Nomad task name | `nginx` |
| `nomad_alloc_id` | `com.hashicorp.nomad.alloc_id` container label | `ba05188a-f761-54ea-a1a2-e24704488c79` |
| `stream` | `stdout` / `stderr` | `stdout` |

Relabel rules that copy optional labels use `regex: "(.+)"`, so a container without that Docker label keeps the default instead of getting an empty value.

## Queries run

Generate some traffic, including deliberate misses:

```bash
for p in / /missing /admin /; do curl -s -o /dev/null -w "%{http_code} $p\n" http://127.0.0.1:<nomad-port>$p; done
# 200 /
# 404 /missing
# 404 /admin
# 200 /
```

1. All logs from the Nomad job:

   ```logql
   {job="nginx-app"}
   ```

2. Only NGINX access-log lines whose status is not 200. This is the query used for the screenshot:

   ```logql
   {job="nginx-app"} |= "HTTP/1" | pattern `<ip> - <_> [<_>] "<method> <path> <_>" <status> <_>` | status != "200"
   ```

   Result (via `curl localhost:3100/loki/api/v1/query_range`):

   ```text
   {job="nginx-app", service="nginx", nomad_alloc_id="ba05188a-...", status="404", path="/missing"}
     172.17.0.1 - - [25/Oct/2026:07:01:33 +0000] "GET /missing HTTP/1.1" 404 146 "-" "curl/8.5.0"
   {job="nginx-app", service="nginx", nomad_alloc_id="ba05188a-...", status="404", path="/admin"}
     172.17.0.1 - - [25/Oct/2026:07:01:33 +0000] "GET /admin HTTP/1.1" 404 146 "-" "curl/8.5.0"
   ```

3. Error rate per path over 5 minutes:

   ```logql
   sum by (path) (count_over_time({job="nginx-app"} |= "HTTP/1" | pattern `<ip> - <_> [<_>] "<method> <path> <_>" <status> <_>` | status =~ "4..|5.." [5m]))
   ```

Screenshot: [Grafana Explore](../docs/screenshots/grafana-explore-loki.jpg)

## Problems hit and how I fixed them

1. **Grafana would not start: `Bind for 0.0.0.0:3000 failed: port is already allocated`.** Another local service already used port 3000. I made the host port configurable (`${GRAFANA_PORT:-3000}:3000`) and started the stack with `GRAFANA_PORT=3001`.
2. **`{job="nginx-app"}` returned nothing for the Nomad allocation.** `docker inspect` showed that Nomad's docker driver only adds `com.hashicorp.nomad.alloc_id` by default, so the `job_name` and `task_name` relabel rules had nothing to read. I added a `labels = { ... }` map with `${NOMAD_JOB_NAME}` and `${NOMAD_TASK_NAME}` to the task's `config` block. My first attempt used block syntax (`labels { ... }`), which fails `nomad job validate` with "Argument names must not be quoted". It has to be a map assignment.
3. **My first "non-200" query also matched NGINX startup messages.** Lines like `/docker-entrypoint.sh: Configuration complete` have no `status` field after `pattern`, and an empty value is `!= "200"`. Adding the line filter `|= "HTTP/1"` before the parser keeps only access-log lines.
