Ensure app is not connected to db
Once slave lag is 0, set read lock in master
Note down master current binlog status
Connect to slave, note down slave status
stop slave
reset slave all
Ensure binlog is enabled in slave
Disable read only in slave if it was enabled
Note down slave binlog file name and position
Go to master, and execute change master to commands with Slave ip as master ip and slave binlog file and position
Ensure there is user created for master to connect to slave
Start slave in master
