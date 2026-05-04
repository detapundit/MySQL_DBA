# MongoDB Migration: High-Level Plan
## 3.4 Sharded Cluster → 8.0 Replica Set

---

## Migration Overview

| Item | Detail |
|---|---|
| Source | MongoDB 3.4.10 sharded cluster (4 mongos, 5-node config replica set, 3 shards × 5 nodes) on RHEL 6.10 |
| Target | MongoDB 8.0 replica set (3 nodes, PSS) on RHEL 9 |
| Data size | ~350 GB (largest collection: 143 GB) |
| Migration method | Logical dump and restore via mongos endpoint |
| Downtime budget | 6 hours |
| Authentication | SCRAM username/password (no TLS) on both ends |

---

## Phase 1: Pre-Implementation (T-7 to T-1 day)

### 1.1 Source Cluster Inventory
- Capture full cluster topology (shards, mongos, config servers)
- Document all sharded collections and their shard keys
- Record per-database and per-collection sizes
- Export complete index inventory for every collection
- Document all users, custom roles, and their privileges

### 1.2 Application Compatibility Audit
- Identify every application connecting to the cluster
- Verify each application's MongoDB driver version supports MongoDB 8.0
- Plan and execute driver upgrades in dev/staging environments
- Document the user → password mapping needed for connection string updates

### 1.3 Capacity & Connectivity Validation
- Confirm sufficient disk space on target nodes (data + indexes + 30% headroom)
- Verify network connectivity from migration host to source mongos and all target nodes
- Run bandwidth test between migration host and target — sustained 1 Gbps is the baseline for the 6-hour window

### 1.4 Backup of Source Cluster (Mandatory)
- Take a full per-shard backup of the source cluster
- Verify the backup by restoring to a scratch instance
- Retain the backup for at least 7 days post-migration

### 1.5 Staging Dry Run (Strongly Recommended)
- Replicate the cutover process end-to-end in a non-production environment
- Use representative data volumes
- Record actual timings for dump, restore, and index rebuild
- Adjust the cutover window estimate based on real measurements

---

## Phase 2: Build the Target Replica Set (T-3 days)

### 2.1 Operating System Preparation
- Install and patch RHEL 9 on all 3 target hosts
- Configure time synchronization (chrony/NTP)
- Disable Transparent Huge Pages
- Set ulimits for open files and processes
- Configure XFS filesystem on the data volume
- Open required firewall ports between cluster nodes and from application servers

### 2.2 MongoDB 8.0 Installation
- Install MongoDB 8.0 server, database tools, and shell on all 3 hosts
- Verify all version numbers

### 2.3 Cluster Initialization
- Generate a shared keyfile for inter-node authentication
- Distribute the keyfile to all 3 nodes with correct ownership and permissions
- Configure each node with the same replica set name, storage settings, and network bindings
- Initiate the replica set with explicit member priorities (one preferred primary)
- Verify all members reach healthy state (1 PRIMARY, 2 SECONDARY)

### 2.4 Authentication Setup
- Create the root admin user on the primary
- Enable authorization and keyfile authentication in configuration
- Perform a rolling restart (secondaries first, primary last) to enable auth without an outage

### 2.5 User Recreation
- Recreate every application user from the source inventory
- Use SCRAM-SHA-256 explicitly (3.4 used SCRAM-SHA-1; defaults differ)
- Recreate any custom roles
- Document the new credentials and share with application teams

### 2.6 Smoke Test the Empty Cluster
- Connect as each application user
- Perform a write, read, and drop operation to confirm authentication and basic functionality
- Cluster is now ready and waiting for cutover day

---

## Phase 3: Cutover (Cutover Day, 6-hour window)

### 3.1 Pre-Flight Checks (15 minutes)
- Verify migration tools are installed and accessible on the bridge host
- Confirm credentials work for both source and target
- Confirm the target cluster is empty and healthy

### 3.2 Stop Application Traffic
- Stop application servers or activate load balancer maintenance mode
- Verify zero application connections remain on the source

### 3.3 Stop the Cluster Balancer
- Stop the balancer on the source cluster
- Wait until any in-flight chunk migrations complete
- Confirm no balancer activity

### 3.4 Capture Validation Baseline
- Record document counts for every collection on the source
- This is the reference for post-restore validation

### 3.5 Execute Data Migration (3–4 hours)
- Run a dump from the source mongos, piped directly into a restore on the target
- Exclude the `config` database (sharded cluster metadata, not needed)
- Exclude the `admin` database (users handled separately)
- Skip index creation during data load to maximize throughput
- Convert any legacy index definitions to 8.0-compatible form
- Monitor throughput, disk growth, and replication lag continuously

### 3.6 Verify Data Restore
- Confirm all expected databases are present on the target
- Capture document counts on the target
- Compare to the source baseline — counts must match exactly

### 3.7 Rebuild Indexes (1–1.5 hours)
- Rebuild all indexes per collection using the source inventory
- Group all indexes for a single collection into one operation (single data scan)
- Run rebuilds for different collections in parallel where I/O permits
- Verify index count and definitions match source after completion

### 3.8 Functional Validation (30 minutes)
- Run application-meaningful sample queries
- Verify aggregations produce expected results
- For the largest collection, run distribution checks to confirm data integrity
- This is the gate before exposing the new cluster to applications

### 3.9 Switch Application Connection Strings
- Update connection strings from the mongos endpoints to the new replica set
- Include replica set name and authentication source parameters
- Coordinate with application teams to deploy the changes

### 3.10 Bring Applications Online
- Start one canary application instance first
- Monitor logs for connection or query errors for 5 minutes
- If clean, bring all remaining instances online
- Monitor cluster connection counts and operation throughput

### 3.11 Cutover Complete
- Document actual completion time
- Notify stakeholders
- Leave the old cluster running but inert for the soak period

---

## Phase 4: Immediate Post-Cutover (T+0 to T+24 hours)

### 4.1 First-Hour Active Monitoring
- Watch application error rates closely
- Monitor database connection counts on the new cluster
- Confirm replication lag remains low
- Enable slow query profiling to capture any unusual patterns

### 4.2 24-Hour Observation
- Hourly checks of replica set health
- Review slow query log for anomalies
- Address any application issues immediately

### 4.3 Backup Configuration
- Set up scheduled backups on the new cluster
- Create a dedicated backup user
- Run and verify the first scheduled backup
- Test restoring from the first backup to a scratch instance within 48 hours

---

## Phase 5: Soak & Decommission (T+1 day to T+14 days)

### 5.1 Soak Period (Minimum 7 Days)
- Old cluster remains running but inert (balancer stopped, no application traffic)
- Daily monitoring of new cluster health, backups, and performance
- Resist any temptation to point applications back at the old cluster

### 5.2 Decommissioning the Old Cluster
- Take a final archival backup of each shard
- Take filesystem snapshots if storage supports it
- Stop mongos instances one at a time, watching for unexpected connections
- Stop shard members
- Stop config server replica set
- Decommission OS/hardware per standard process

---

## Rollback Strategy

| Stage | Rollback approach |
|---|---|
| Before application connection switch | Clean rollback — restart balancer on old cluster, restart applications. No data loss. |
| Within minutes of connection switch | Switch connection strings back. Reconcile any new writes manually if needed. |
| Hours after cutover | Treat as a one-way door. Roll back means losing all writes since cutover. Fix forward is preferred. |

The rigor of pre-cutover validation (Section 3.6 to 3.8) is what prevents the late-rollback scenario from occurring.

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Migration takes longer than 6-hour window | Staging dry run to validate timings; piped dump→restore eliminates transfer step; deferred index builds |
| Source–target compatibility issues with 3.4 BSON dumps | `--convertLegacyIndexes` flag; staging dry run validates compatibility |
| Application driver incompatible with 8.0 | Driver audit and upgrades completed in Phase 1.2 before cutover |
| User authentication failures post-cutover | Manual recreation with SCRAM-SHA-256 in Phase 2.5; smoke test in Phase 2.6 |
| Network failure during piped restore | Bandwidth test in Phase 1.3; restore restart plan documented |
| Data loss undetected | Document count comparison gates (Phase 3.6); functional validation (Phase 3.8); old cluster retained for soak period |
| Performance regression on new cluster | Slow query profiling enabled in Phase 4.1; baseline metrics captured for comparison |

---

## Sign-Off Gates

The cutover proceeds only when all gates are met:

**Pre-cutover (T-1 day):**
- All Phase 1 inventory and audits complete
- Target cluster built, healthy, and validated
- All application users recreated and tested
- Driver compatibility confirmed for all applications
- Source backup taken and restore-tested
- Staging dry run completed with measured timings
- Stakeholder approval recorded

**Cutover validation gates:**
- Source and target document counts match exactly
- All indexes rebuilt and verified against source inventory
- Functional validation queries pass
- Canary application instance healthy

**Post-cutover (T+24 hours):**
- No abnormal application errors in 24-hour window
- Replication lag consistently low
- First scheduled backup successful

---

## Roles and Responsibilities

| Role | Responsibility |
|---|---|
| DBA Lead | Owns the runbook execution, makes go/no-go decisions at validation gates |
| DBA Support | Monitoring, validation queries, index rebuild execution |
| Application Owners | Stop/start applications, validate functionality post-cutover, sign off on application health |
| Network/Infrastructure | Connectivity verification, firewall changes, target host provisioning |
| Change Manager | Stakeholder communication, change ticket management |

---

## Estimated Timeline

| Phase | Window |
|---|---|
| Pre-implementation | T-7 to T-1 day |
| Target build | T-3 days |
| Cutover | 6 hours |
| Active post-cutover monitoring | T+0 to T+24 hours |
| Soak | 7 days minimum |
| Decommission | After T+7 days, on stakeholder sign-off |

---

*High-level plan accompanying the detailed execution runbook. For commands and technical detail, refer to the execution runbook document.*
