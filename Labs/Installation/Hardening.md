
mysql_secure_installation


validate_password.length=12
validate_password.mixed_case_count=1
validate_password.number_count=1
validate_password.special_char_count=1
validate_password.policy=MEDIUM


firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.0.5/32 port protocol=tcp port="3306" accept'
firewall-cmd --reload


secure-file-priv=/var/lib/mysql-files
local_infile=OFF
chmod 750 /var/lib/mysql
chown -R mysql:mysql /var/lib/mysql



###############


1️⃣ InnoDB Buffer Pool Size

50–70% of total server RAM
Example: For 16GB RAM:

innodb_buffer_pool_size = 8G


2️⃣ Enable Multiple Buffer Pool Instances
innodb_buffer_pool_instances = 8

3️⃣ Log File Size

For write-heavy workloads:

innodb_log_file_size = 1G
innodb_log_files_in_group = 2


4️⃣ Flush Method
innodb_flush_method = O_DIRECT

5️⃣ Increase File Descriptors
innodb_open_files = 65535
open_files_limit = 65535

6️⃣ Increase Thread Concurrency
thread_cache_size = 100


9️⃣ Enable Slow Query Log
slow_query_log = ON
slow_query_log_file = /var/log/mysql-slow.log
long_query_time = 1
log_queries_not_using_indexes = OFF

🔟 Adjust max_connections

Typical values:

max_connections = 200

1️⃣ Enable Binary Logs (Point-in-Time Recovery)
log_bin = mysql-bin
binlog_expire_logs_seconds = 604800   # 7 days


############################


OS-LEVEL TUNING (Linux)


1️⃣ Increase Linux File Descriptor Limit

Create:

/etc/security/limits.d/mysql.conf
Add:

mysql soft nofile 65535
mysql hard nofile 65535

2️⃣ Disable NUMA (Important!)

Check:

numactl --show


If NUMA available → install MySQL with:

numactl --interleave=all mysqld

3️⃣ Set I/O Scheduler to "none" or "deadline" for SSD
echo none > /sys/block/sda/queue/scheduler

4️⃣ Disable HugePages for MySQL
echo never > /sys/kernel/mm/transparent_hugepage/enabled

5️⃣ Sysctl Network Tuning

Create /etc/sysctl.d/mysql.conf:

vm.swappiness=1
fs.aio-max-nr=262144
net.core.somaxconn=65535
net.ipv4.tcp_fin_timeout=10

Apply
sysctl --system
