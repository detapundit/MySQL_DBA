--- List the privileges available

In 8.0, a caching password is the default authentication plugin.
We can have a user name up to 32 characters

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

--- Dual password
In 8.0.14, we have the ability to create what's called a dual password support. Now, we have to have RETAIN CURRENT PASSWORD clause if we want to maintain that older password
The new password is considered the primary. The old password is considered the secondary.
And then once we no longer want that secondary, we can go ahead and alter that user. And we discard that old password.

  ALTER USER USER() identified by 'newPassWorD$' RETAIN CURRENT PASSWORD;
  ALTER USER USER() DISCARD OLD PASSWORD;

--- Password expiration. They can login with expired passwords but need to change it first
--- We can configure password expiration. We can set a default for our system, default_password_lifetime. The default value is 0
  
  create user appusr@localhost identified by 'Password@1' PASSWORD EXPIRE;

  alter user testusr@localhost PASSWORD EXPIRE;
  
   alter user testusr@localhost PASSWORD EXPIRE DEFAULT;
   alter user testusr@localhost PASSWORD EXPIRE INTERVAL 30 DAY;
   alter user testusr@localhost PASSWORD EXPIRE NEVER;
  
--- To change password for particular user

mysql> alter user root@localhost identified by 'Password@1';






