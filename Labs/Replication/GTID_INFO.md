MySQL, starting with version 5.6 and above, allows users to make use of MySQL GTIDs to set up replication for their MySQL database. 
Each GTID acts as a unique Id that MySQL generates and associates with every transaction that takes place within your database.

It makes use of a unique transaction number and the master server’s UUID to identify each transaction. 
It thereby ensures a simple failover and recovery process by keeping track of each replication-based transaction between the master and slave server.

When the replication takes place, the slave makes use of the same MySQL GTIDs, irrespective of whether it acts as a master for any other nodes or not. 
With each transaction replication, the same MySQL GTIDs and transaction numbers also come along from the master and the slave will write these to the binlog if it’s configured to write its data events.

To ensure a smooth, consistent, and fault-tolerant replication, the slave will then inform the master of the MySQL GTIDs that were a part of the execution, which helps the master node identify if any transaction did not take place. 
The master node then informs the slave to carry out the left-over transactions and thereby ensures that data replication takes place accurately.
