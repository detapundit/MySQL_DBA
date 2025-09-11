# MySQL — History, Major Forks, and Current Versions

---

## 1. History & evolution (concise)

**Origins (1994–2003)**  
- MySQL development began in 1994; first public releases appeared in the mid-1990s.  
- It gained popularity for speed, simplicity and became central to the LAMP stack.

**Growth and transactional engines (2004–2008)**  
- MySQL introduced richer SQL features and adopted InnoDB as its primary transactional storage engine.  
- Innobase was acquired by Oracle in 2005.

**Acquisitions and the community response (2008–2010)**  
- Sun Microsystems acquired MySQL AB in 2008.  
- Oracle acquired Sun (and MySQL) in 2010.  
- Concerns about Oracle's stewardship motivated forks and alternative projects.

---

## 2. Notable forks and variants

**MariaDB**  
Forked by Monty Widenius in 2009 to maintain a community-driven, fully open alternative.  
Adds storage engines (Aria, ColumnStore, MyRocks) and some diverging features.

**Percona Server for MySQL**  
Drop-in replacement focused on performance, stability, and observability.  
Provides tools like Percona XtraBackup and enhanced instrumentation.

**Drizzle**  
An earlier experimental fork aimed at a lightweight, modular server.  
Now mostly inactive but influenced design ideas.

**Amazon Aurora (MySQL-compatible)**  
Cloud-native, MySQL-protocol-compatible engine by AWS.  
Uses distributed storage subsystem and fast failover semantics.

**Other vendors**  
Numerous enterprise editions exist; MariaDB and Percona remain the principal community forks.

---

## 3. Current major releases (2025-09-10 snapshot)

- **Oracle MySQL**: MySQL 8.0.43 (GA July 22, 2025)  
- **MariaDB**: 10.6.23 (released Aug 6, 2025)  
- **Percona Server**: 8.4.6-6 (released Sep 8, 2025)  
- **Amazon Aurora**: Aurora MySQL 3.x (e.g., 3.10.0, compatible with MySQL 8.0.42 as of July 31, 2025)

---

## 4. Quick cheatsheet

| Aspect          | Oracle MySQL               | MariaDB                   | Percona Server            | Amazon Aurora |
|-----------------|----------------------------|---------------------------|---------------------------|---------------|
| Primary engine  | InnoDB                     | Aria/InnoDB/MyRocks       | XtraDB/InnoDB             | Aurora engine |
| Replication     | Group Replication, Async   | Async, Galera             | Async, Semi-sync, GTID    | Aurora Replicas |
| Focus           | Reference implementation   | Community-driven          | Performance & observability | Cloud-native HA |
| Licensing       | GPL + Enterprise           | GPL community             | GPL community             | AWS-managed |

---

## 5. Choosing between them (guidance)

- **Oracle MySQL** → use for official compatibility and enterprise-only features.  
- **MariaDB** → use if you prefer a community-led fork with distro support and alternative engines.  
- **Percona Server** → use when performance tuning, observability, and Percona tooling are important.  
- **Amazon Aurora** → use for a managed, highly available cloud-native MySQL-compatible service.

---

## 6. References

- MySQL 8.0.43 release notes (Oracle)  
- MariaDB 10.6.23 release notes  
- Percona Server for MySQL 8.4.6-6 release announcement  
- Amazon Aurora MySQL release notes (Aurora MySQL 3.x compatibility info)

---

*Generated: 2025-09-10 — concise technical summary.*
