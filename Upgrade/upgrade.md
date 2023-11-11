# MySQL 5.7 to MySQl 8 upgrade

Install mysql shell

    yum install mysql-shell

# Login to mysql shell

    mysqlsh
    \connect root@localhost
    util.checkForServerUpgrade('root@localhost', {configpath: "/etc/my.cnf"})  

# If 0 errors, then proceed with next step

Stop mysql service

    systemctl stop mysqld

# Enable mysql8 repo

# Run yum update
    yum update

# Update mysql package

    yum update mysql-server

# Start mysql service 

    systemctl start mysqld

# Login to mysql and confirm version
