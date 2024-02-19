    sudo yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
    sudo percona-release setup pxc-80
    sudo yum install percona-xtradb-cluster

    sudo service mysql start
    sudo grep 'temporary password' /var/log/mysqld.log

    mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootPass';
    mysql> exit
    sudo service mysql stop

    
  Node 1	pxc1	172.31.33.114
  Node 2	pxc2	172.31.33.61
  Node 3	pxc3	172.31.41.14
    

**writeset replication parameters**

  **Below parameters across all nodes**

    wsrep_provider=/usr/lib64/galera4/libgalera_smm.so
    wsrep_cluster_name=pxc-cluster
    wsrep_cluster_address=gcomm://172.31.33.114,172.31.33.61,172.31.41.14
    pxc_strict_mode=ENFORCING
    pxc_encrypt_cluster_traffic=OFF
    
On node1

    wsrep_node_name=pxc1
    wsrep_node_address=172.31.33.114

On node2   
    
    wsrep_node_name=pxc2
    wsrep_node_address=172.31.33.61

On node3

    wsrep_node_name=pxc3
    wsrep_node_address=172.31.41.14
    
**Bootstrap any one node first**
    
    systemctl start mysql@bootstrap.service
    show status like 'wsrep%';
    
**Star other nodes**
    
    systemctl start mysql
    show status like 'wsrep%';

    mysql> show global status where variable_name in ('wsrep_provider_name','wsrep_cluster_size','wsrep_cluster_status');
    +----------------------+---------+
    | Variable_name        | Value   |
    +----------------------+---------+
    | wsrep_cluster_size   | 3       |
    | wsrep_cluster_status | Primary |
    | wsrep_provider_name  | Galera  |
    +----------------------+---------+
    3 rows in set (0.00 sec)
