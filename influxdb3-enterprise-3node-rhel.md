# InfluxDB 3 Enterprise — 3-Node Cluster on RHEL 8.10 (Production Runbook)

A step-by-step production guide for installing a 3-node InfluxDB 3 Enterprise cluster on RHEL 8.10 EC2 instances, with database setup, sample data ingestion, the Explorer web UI, and a backup strategy.

---

## 1. Architecture Overview

InfluxDB 3 Enterprise is **diskless** — all persisted data lives in a shared object store. Nodes are stateless compute units that share that store. There are no "meta nodes" like InfluxDB 1.x.

For 3 nodes, the recommended production layout is:

| Node | Hostname (example) | Mode | Role |
|------|---------------------|------|------|
| Node 1 | `influx-node01` | `ingest,query` | Writer + Reader (HA replica) |
| Node 2 | `influx-node02` | `ingest,query` | Writer + Reader (HA replica) |
| Node 3 | `influx-node03` | `compact` | Dedicated compactor (single instance only) |

**Critical rule**: Only ONE node in the cluster may run in `compact` mode.

You also need a shared object store. The two recommended options on AWS:
- **Option A (recommended): AWS S3** — managed, durable, scales infinitely.
- **Option B: MinIO** — self-hosted S3-compatible store on one of the nodes (or a 4th host) if you can't use S3.

This guide uses **AWS S3**. A short MinIO appendix is included at the end.

---

## 2. Prerequisites & EC2 Sizing

### EC2 instance recommendations

| Role | Instance type (minimum) | EBS (gp3) | Notes |
|------|-------------------------|-----------|-------|
| Ingest/Query node | `m6i.2xlarge` (8 vCPU / 32 GB) | 200 GB | WAL & local cache live here |
| Compactor | `c6i.4xlarge` (16 vCPU / 32 GB) | 100 GB | CPU-heavy workload |

License limits are based primarily on CPU cores — pick instance sizes that match your license tier.

### Network / security group rules

Open the following between all 3 nodes and from your admin/Explorer host:

| Port | Direction | Purpose |
|------|-----------|---------|
| 8181 | inbound to all nodes | InfluxDB 3 HTTP API (writes & queries) |
| 22 | inbound from your IP | SSH admin |
| 8888 | inbound to Explorer host | Explorer UI (HTTPS) |

All nodes must also reach `s3.<region>.amazonaws.com` (HTTPS / 443) for the shared bucket.

### OS prerequisites (run on all 3 nodes)

```bash
# Update system
sudo dnf update -y

# Useful tools
sudo dnf install -y wget curl jq tar unzip chrony policycoreutils-python-utils

# Time sync — REQUIRED for cluster consistency
sudo systemctl enable --now chronyd
chronyc tracking

# Disable swap (recommended by InfluxData)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Increase file descriptor limits
echo 'influxdb soft nofile 65536' | sudo tee -a /etc/security/limits.conf
echo 'influxdb hard nofile 65536' | sudo tee -a /etc/security/limits.conf

# Open firewall (firewalld)
sudo firewall-cmd --permanent --add-port=8181/tcp
sudo firewall-cmd --reload
```

### /etc/hosts — make all nodes resolvable

On every node, add:

```
10.0.1.11   influx-node01
10.0.1.12   influx-node02
10.0.1.13   influx-node03
```

(Replace with your actual private IPs.)

---

## 3. Create the Shared S3 Bucket

From your laptop or admin machine (with AWS CLI configured):

```bash
# Pick a globally-unique bucket name in the same region as your EC2s
export AWS_REGION=ap-south-1
export BUCKET=influxdb3-enterprise-prod-<your-suffix>

aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

# Enable versioning (helps with accidental deletes / restore)
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# Block all public access
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Default encryption
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

### IAM — best practice is an instance role, not access keys

Create an IAM policy (`influxdb3-s3-policy.json`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::influxdb3-enterprise-prod-<your-suffix>"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::influxdb3-enterprise-prod-<your-suffix>/*"
    }
  ]
}
```

Attach it to an IAM role (e.g. `InfluxDB3NodeRole`) and attach the role to all 3 EC2 instances. With an instance role, you don't need to set `--aws-access-key-id` / `--aws-secret-access-key` on the command line.

---

## 4. Install InfluxDB 3 Enterprise on All 3 Nodes

Run the following on **each of the 3 nodes**:

```bash
# Run the official installer — installs the influxdb3 binary
curl -O https://www.influxdata.com/d/install_influxdb3.sh
sh install_influxdb3.sh enterprise

# The installer puts the binary at ~/.influxdb/influxdb3 by default.
# Move it to /usr/local/bin for system-wide access:
sudo mv ~/.influxdb/influxdb3 /usr/local/bin/influxdb3
sudo chmod 755 /usr/local/bin/influxdb3

# Verify
influxdb3 --version
```

### Create a dedicated service user and directories

```bash
sudo useradd --system --no-create-home --shell /sbin/nologin influxdb

# Local cache / plugin / log directories (object store is on S3, but these are needed locally)
sudo mkdir -p /var/lib/influxdb3 /var/log/influxdb3 /etc/influxdb3 /var/lib/influxdb3/plugins
sudo chown -R influxdb:influxdb /var/lib/influxdb3 /var/log/influxdb3 /etc/influxdb3
```

---

## 5. Configure Each Node as a systemd Service

### Common environment file (same on all 3 nodes)

Create `/etc/influxdb3/influxdb3.env`:

```bash
sudo tee /etc/influxdb3/influxdb3.env > /dev/null <<'EOF'
# Shared cluster ID — MUST be identical on all nodes
INFLUXDB3_CLUSTER_ID=prod-cluster01

# Object store config (same on all nodes)
INFLUXDB3_OBJECT_STORE=s3
INFLUXDB3_BUCKET=influxdb3-enterprise-prod-<your-suffix>
AWS_DEFAULT_REGION=ap-south-1

# Telemetry / logging
LOG_FILTER=info

# License email (for trial / at-home licenses; commercial uses license file)
INFLUXDB3_ENTERPRISE_LICENSE_EMAIL=ops@yourcompany.com
EOF

sudo chmod 640 /etc/influxdb3/influxdb3.env
sudo chown root:influxdb /etc/influxdb3/influxdb3.env
```

If you're not using an EC2 instance role, also append your AWS credentials (less secure):

```
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

### Per-node systemd unit

#### Node 1 (`influx-node01`) — ingest + query

`/etc/systemd/system/influxdb3.service`:

```ini
[Unit]
Description=InfluxDB 3 Enterprise
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=influxdb
Group=influxdb
EnvironmentFile=/etc/influxdb3/influxdb3.env
ExecStart=/usr/local/bin/influxdb3 serve \
    --node-id host01 \
    --cluster-id ${INFLUXDB3_CLUSTER_ID} \
    --mode ingest,query \
    --object-store ${INFLUXDB3_OBJECT_STORE} \
    --bucket ${INFLUXDB3_BUCKET} \
    --aws-default-region ${AWS_DEFAULT_REGION} \
    --http-bind 0.0.0.0:8181 \
    --data-dir /var/lib/influxdb3 \
    --plugin-dir /var/lib/influxdb3/plugins
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

#### Node 2 (`influx-node02`) — ingest + query

Same as Node 1 except `--node-id host02`.

#### Node 3 (`influx-node03`) — dedicated compactor

Same unit file but the `ExecStart` becomes:

```
ExecStart=/usr/local/bin/influxdb3 serve \
    --node-id host03 \
    --cluster-id ${INFLUXDB3_CLUSTER_ID} \
    --mode compact \
    --object-store ${INFLUXDB3_OBJECT_STORE} \
    --bucket ${INFLUXDB3_BUCKET} \
    --aws-default-region ${AWS_DEFAULT_REGION} \
    --http-bind 0.0.0.0:8181 \
    --data-dir /var/lib/influxdb3 \
    --plugin-dir /var/lib/influxdb3/plugins
```

### Start the service on each node

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now influxdb3
sudo systemctl status influxdb3
sudo journalctl -u influxdb3 -f      # tail logs
```

### License activation (first-run, on Node 1 only)

The first time the server starts, it prompts for a license type. Because `INFLUXDB3_ENTERPRISE_LICENSE_EMAIL` is set in the env file, the trial license auto-generates after you click the verification link emailed to you. The license file is written into the **shared S3 bucket** under `<cluster-id>/trial_or_home_license` (or `commercial_license`), so it applies cluster-wide automatically — you do **not** need to repeat the licensing step on Nodes 2 and 3.

For a commercial license, place the JSON license file from InfluxData on Node 1 and start with `--license-file /etc/influxdb3/license.json` once; it gets uploaded to S3 and consumed by all nodes.

### Verify cluster health

From any node:

```bash
curl http://localhost:8181/health
# {"status":"pass","checks":[]}

influxdb3 show nodes --host http://localhost:8181 --token <admin-token-from-next-step>
```

---

## 6. Create the Operator (Admin) Token

Authorization is on by default. The first admin token you create is the **operator token** — it never expires and can do everything. Generate it on **Node 1** only:

```bash
influxdb3 create token --admin --host http://localhost:8181
```

Output (one-time only — store securely!):

```
Token: apiv3_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Save this immediately** in your secrets manager (AWS Secrets Manager, Vault, etc.). You cannot retrieve it later.

Export it for subsequent CLI calls:

```bash
export INFLUXDB3_AUTH_TOKEN='apiv3_xxxxxxxxxxxxxx...'
```

(Add to `~/.bashrc` or equivalent on your admin host.)

### Create scoped resource tokens (recommended for apps)

```bash
# A write token for an application
influxdb3 create token \
  --permission "db:metrics:write" \
  --name app-writer \
  --host http://localhost:8181

# A read-only token for dashboards
influxdb3 create token \
  --permission "db:metrics:read" \
  --name dashboard-reader \
  --host http://localhost:8181
```

---

## 7. Create a Database and Insert Sample Data

### Create a database

```bash
influxdb3 create database metrics \
  --host http://influx-node01:8181 \
  --token "$INFLUXDB3_AUTH_TOKEN"

# List
influxdb3 show databases --host http://influx-node01:8181 --token "$INFLUXDB3_AUTH_TOKEN"
```

In InfluxDB 3, schema is implicit — tables and columns are created on the first write. There's no separate `CREATE TABLE`.

### Insert sample data via line protocol

Send writes to one of your **ingest** nodes (Node 1 or Node 2), never the compactor.

#### Method A — `influxdb3 write` CLI

```bash
cat > /tmp/sample.lp <<'EOF'
cpu,host=server-a,region=ap-south-1 usage_user=23.5,usage_system=11.2 1714805000000000000
cpu,host=server-b,region=ap-south-1 usage_user=18.1,usage_system=7.4  1714805000000000000
cpu,host=server-a,region=ap-south-1 usage_user=27.0,usage_system=12.8 1714805060000000000
cpu,host=server-b,region=ap-south-1 usage_user=21.6,usage_system=9.1  1714805060000000000
mem,host=server-a,region=ap-south-1 used_percent=64.2 1714805000000000000
mem,host=server-b,region=ap-south-1 used_percent=58.7 1714805000000000000
EOF

influxdb3 write \
  --database metrics \
  --file /tmp/sample.lp \
  --host http://influx-node01:8181 \
  --token "$INFLUXDB3_AUTH_TOKEN"
```

#### Method B — HTTP API (v3 native)

```bash
curl -X POST "http://influx-node01:8181/api/v3/write_lp?db=metrics&precision=nanosecond" \
  -H "Authorization: Bearer $INFLUXDB3_AUTH_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary @/tmp/sample.lp
```

#### Method C — InfluxDB v2-compatible API (works with Telegraf out of the box)

```bash
curl -X POST "http://influx-node01:8181/api/v2/write?bucket=metrics&precision=ns" \
  -H "Authorization: Token $INFLUXDB3_AUTH_TOKEN" \
  --data-binary @/tmp/sample.lp
```

### Query the data — SQL (default in v3)

Send queries to either ingest+query node:

```bash
influxdb3 query \
  --database metrics \
  --host http://influx-node02:8181 \
  --token "$INFLUXDB3_AUTH_TOKEN" \
  "SELECT host, AVG(usage_user) AS avg_user FROM cpu GROUP BY host"
```

### Query via HTTP

```bash
curl -G "http://influx-node02:8181/api/v3/query_sql" \
  -H "Authorization: Bearer $INFLUXDB3_AUTH_TOKEN" \
  --data-urlencode "db=metrics" \
  --data-urlencode "q=SELECT * FROM cpu ORDER BY time DESC LIMIT 10" \
  --data-urlencode "format=json"
```

InfluxQL is also supported via `/api/v3/query_influxql` for backward compatibility.

---

## 8. Install InfluxDB 3 Explorer (Web UI)

Explorer is a separate Docker container that talks to your cluster over HTTP. The simplest production placement is on a **dedicated small EC2 host** (e.g. `t3.medium`) so it doesn't compete with the database for resources. You can also run it on Node 1 if cost is a concern.

### Install Docker on the Explorer host

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

### Run Explorer (admin mode, persistent storage, pre-configured server)

```bash
mkdir -p ~/explorer/{db,config,ssl}
sudo chown -R 1500:1500 ~/explorer/db   # container runs as uid 1500

# Pre-configure the InfluxDB server connection
cat > ~/explorer/config/config.json <<'EOF'
{
  "DEFAULT_INFLUX_SERVER": "http://influx-node01:8181",
  "DEFAULT_INFLUX_DATABASE": "metrics",
  "DEFAULT_API_TOKEN": "apiv3_xxxxxxxxxxxxxx...",
  "DEFAULT_SERVER_NAME": "Production Cluster"
}
EOF
chmod 600 ~/explorer/config/config.json

# Generate a strong session secret
SECRET=$(openssl rand -base64 48)

# Start Explorer in admin mode
docker run --detach \
  --name influxdb3-explorer \
  --restart unless-stopped \
  --publish 8888:8443 \
  --volume ~/explorer/db:/db:rw \
  --volume ~/explorer/config:/app-root/config:ro \
  --volume ~/explorer/ssl:/etc/nginx/ssl:ro \
  --env SESSION_SECRET_KEY="$SECRET" \
  influxdata/influxdb3-ui:1.8.0 \
  --mode=admin
```

For production, generate a real TLS cert (Let's Encrypt or your internal CA), drop `server.crt` and `server.key` into `~/explorer/ssl/`, and use port `8443` mapped to `8888`. For an internal-only quickstart, you can publish `8080:8080` and use HTTP, but **don't do that on a public IP**.

### Access

Open `https://<explorer-host>:8888` in your browser. Because you pre-configured `config.json` with the admin token, Explorer connects automatically — you can browse databases, write data, run queries, manage tokens, set retention, and view query history all from the UI.

### Modes

- `--mode=admin` — full administrative access (token mgmt, DB creation, etc.)
- `--mode=query` (default) — read-only / query-only

---

## 9. Backup Strategy

InfluxDB 3 Enterprise has **no built-in backup tool** — backups are file-level copies of the shared object store. Order matters: copy in a sequence that minimizes the chance of an inconsistent snapshot.

### What to back up

| Path | Description |
|------|-------------|
| `<cluster_id>/_catalog_checkpoint` | Catalog checkpoint |
| `<cluster_id>/catalog/` | Catalog change log |
| `<cluster_id>/enterprise` | Enterprise config |
| `<cluster_id>/commercial_license` or `trial_or_home_license` | License file |
| `<node_id>/wal/` | Write-ahead log per node |
| `<node_id>/snapshots/` | Snapshot files |
| `<node_id>/dbs/<db>/<table>/<date>/` | Parquet data files |
| `<node_id>/cs`, `cd`, `c` | Compactor-only directories (Node 3) |

The `<node_id>/table-snapshots/` directory regenerates on restart — skip it.

### Backup script (S3 → S3, run from Node 1 or a backup host with S3 access)

Save as `/usr/local/bin/influxdb3-backup.sh`:

```bash
#!/bin/bash
set -euo pipefail

CLUSTER_ID="prod-cluster01"
COMPACTOR_NODE="host03"
DATA_NODES=("host01" "host02")
SOURCE_BUCKET="influxdb3-enterprise-prod-<your-suffix>"
BACKUP_BUCKET="influxdb3-backups-<your-suffix>"
BACKUP_PREFIX="backup-$(date -u +%Y%m%d-%H%M%S)"

echo ">>> Backup starting: s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}"

# 1. Compactor first (it's the source of truth for compacted parquet)
echo "[1/4] Compactor node directories..."
for SUB in cs cd c; do
  aws s3 sync "s3://${SOURCE_BUCKET}/${COMPACTOR_NODE}/${SUB}" \
              "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${COMPACTOR_NODE}/${SUB}/"
done

# 2. All nodes' snapshots, dbs, wal
echo "[2/4] All node data..."
ALL_NODES=("${DATA_NODES[@]}" "${COMPACTOR_NODE}")
for NODE in "${ALL_NODES[@]}"; do
  for SUB in snapshots dbs wal; do
    aws s3 sync "s3://${SOURCE_BUCKET}/${NODE}/${SUB}" \
                "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${NODE}/${SUB}/" || true
  done
done

# 3. Cluster catalog & checkpoint
echo "[3/4] Cluster catalog..."
aws s3 sync "s3://${SOURCE_BUCKET}/${CLUSTER_ID}/catalog" \
            "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${CLUSTER_ID}/catalog/"
aws s3 cp   "s3://${SOURCE_BUCKET}/${CLUSTER_ID}/_catalog_checkpoint" \
            "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${CLUSTER_ID}/"
aws s3 cp   "s3://${SOURCE_BUCKET}/${CLUSTER_ID}/enterprise" \
            "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${CLUSTER_ID}/"

# 4. License (one of these will exist)
echo "[4/4] License files..."
aws s3 cp "s3://${SOURCE_BUCKET}/${CLUSTER_ID}/commercial_license" \
          "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${CLUSTER_ID}/" 2>/dev/null || true
aws s3 cp "s3://${SOURCE_BUCKET}/${CLUSTER_ID}/trial_or_home_license" \
          "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${CLUSTER_ID}/" 2>/dev/null || true

echo ">>> Backup complete: s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}"
```

```bash
sudo chmod 750 /usr/local/bin/influxdb3-backup.sh
```

### Schedule with systemd timer (preferred over cron on RHEL 8)

`/etc/systemd/system/influxdb3-backup.service`:

```ini
[Unit]
Description=InfluxDB 3 Enterprise nightly S3 backup

[Service]
Type=oneshot
ExecStart=/usr/local/bin/influxdb3-backup.sh
StandardOutput=journal
StandardError=journal
```

`/etc/systemd/system/influxdb3-backup.timer`:

```ini
[Unit]
Description=Run InfluxDB 3 backup nightly at 02:30 UTC

[Timer]
OnCalendar=*-*-* 02:30:00 UTC
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now influxdb3-backup.timer
systemctl list-timers | grep influxdb3
```

### Restore process (high level)

Restore is the **reverse** order of backup, with all InfluxDB nodes stopped:

1. Stop `influxdb3` on all 3 nodes (`sudo systemctl stop influxdb3`).
2. Restore `<cluster_id>/_catalog_checkpoint`, `catalog/`, `enterprise`, and license file first.
3. Restore each node's `snapshots/`, `dbs/`, `wal/`.
4. Restore the compactor's `cs/`, `cd/`, `c/` directories last.
5. Start data nodes first, then the compactor.

> **License gotcha**: An InfluxDB 3 Enterprise license is bound to *endpoint + bucket name + region + cluster-id*. Restoring into a different bucket or region invalidates the license — request a DR license from InfluxData support in advance for any disaster-recovery target.

### Recovery point

Recovery succeeds to the latest **snapshot** captured in the backup. Anything written after the most recent WAL flush included in the backup may be lost. Run backups during low-traffic windows for the most consistent results, or use a snapshot-capable underlying storage layer (e.g. S3 point-in-time replication).

---

## 10. Operations Quick Reference

| Task | Command |
|------|---------|
| Start / stop node | `sudo systemctl start|stop influxdb3` |
| Live logs | `sudo journalctl -u influxdb3 -f` |
| Cluster nodes | `influxdb3 show nodes --host http://influx-node01:8181 --token $TOKEN` |
| List databases | `influxdb3 show databases --host ... --token ...` |
| Show license | `influxdb3 show license --host ... --token ...` |
| Health check | `curl http://localhost:8181/health` |
| Set retention | `influxdb3 update database metrics --retention-period 30d --host ... --token ...` |
| Create LVC | `influxdb3 create last_cache --database metrics --table cpu --host ... --token ...` |

### Routing recommendation

In front of the cluster, place an internal **NLB or HAProxy** with two listeners:

- `:8181/write` → Node 1 + Node 2 (round-robin, ingest path)
- `:8181/query` → Node 1 + Node 2 (round-robin, query path)
- Never route client traffic to the compactor (Node 3).

---

## Appendix A — MinIO instead of S3

If you need to keep everything on-prem / inside the EC2 cluster, run MinIO on a 4th host (or co-located on Node 3) and point all InfluxDB nodes at it:

```
ExecStart=/usr/local/bin/influxdb3 serve \
    --node-id host01 \
    --cluster-id prod-cluster01 \
    --mode ingest,query \
    --object-store s3 \
    --bucket influxdb3 \
    --aws-access-key-id minio-access-key \
    --aws-secret-access-key minio-secret-key \
    --aws-endpoint http://minio.internal:9000 \
    --aws-allow-http \
    --http-bind 0.0.0.0:8181
```

For real production durability, MinIO must itself be deployed in distributed mode (4+ disks) — a single-node MinIO is a single point of failure.

---

## Appendix B — SELinux notes

RHEL 8.10 ships with SELinux in `enforcing` mode. The `influxdb3` binary running under a non-standard service user usually works without policy changes, but if you see denials in `journalctl -u influxdb3`:

```bash
sudo ausearch -m avc -ts recent
sudo audit2allow -a -M influxdb3-local
sudo semodule -i influxdb3-local.pp
```

Avoid `setenforce 0` in production.

---

## Appendix C — Useful URLs

- Install docs: https://docs.influxdata.com/influxdb3/enterprise/install/
- Multi-node setup: https://docs.influxdata.com/influxdb3/enterprise/get-started/multi-server/
- Backup / restore: https://docs.influxdata.com/influxdb3/enterprise/admin/backup-restore/
- Explorer: https://docs.influxdata.com/influxdb3/explorer/
- Configuration reference: https://docs.influxdata.com/influxdb3/enterprise/reference/config-options/
- Token management: https://docs.influxdata.com/influxdb3/enterprise/admin/tokens/
