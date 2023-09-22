--- List the privileges available

mysql> show privileges;

--- User details are stored under mysql database in "user" table
--- To check list of users present in database

mysql> use mysql;
mysql> select user,host from user;
+------------------+-----------+
| user             | host      |
+------------------+-----------+
| girish           | localhost |
| mysql.infoschema | localhost |
| mysql.session    | localhost |
| mysql.sys        | localhost |
| root             | localhost |
| testusr          | localhost |
+------------------+-----------+

--- To create a new user with access via localhost and give permissions to run only select queries on any database

mysql> create user appuser@localhost identified by 'Password@1';
mysql> grant select on *.* to appuser@localhost;

--- To check privileges of any user

mysql> show grants for appuser@localhost;

--- To create a new user with access via particular IP and give permissions to run only select,insert,update, delete queries on any database

mysql> create user rwuser@'172.4.3.67' identified by 'Password@1';
mysql> grant select,insert, update, delete on *.* to rwuser@'172.4.3.67';

--- To create a new user with access via particular IP range and give permissions to run only select,insert,update, delete queries on any database
mysql> create user rwuser@'172.4.%' identified by 'Password@1';
mysql> grant select,insert, update, delete on *.* to rwuser@'172.4.%';

--- To create a new user with access via particular IP and give all permissions except grant option on employees database
--- Avoid giving grant option to non-root/non-admin users

mysql> create user dbuser@'172.4.3.67' identified by 'Password@1';
mysql> grant all on employees.* to dbuser@'172.4.3.67';

--- To remove permissions for a particular user, first check what all permissions they have and then remove it

mysql> show grants for rwuser@'172.4.3.67';
mysql> revoke delete on *.* from rwuser@'172.4.3.67';

--- To delete/drop a user from a database

mysql> drop user rwuser@'172.4.3.67';

--- To change password for existing user

mysql> alter user root@localhost identified by 'Password@1';






