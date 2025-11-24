

          wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.40-1.el8.x86_64.rpm-bundle.tar
          tar -xvf mysql-8.0.40-1.el8.x86_64.rpm-bundle.tar


          | Package                              | Purpose                      |
          | ------------------------------------ | ---------------------------- |
          | `mysql-community-client.rpm`         | MySQL client                 |
          | `mysql-community-server.rpm`         | MySQL server                 |
          | `mysql-community-common.rpm`         | Core configs                 |
          | `mysql-community-libs.rpm`           | Core libs                    |
          | `mysql-community-libs-compat.rpm`    | Compatibility libs           |
          | `mysql-community-client-plugins.rpm` | Auth plugins                 |
          | `mysql-community-devel.rpm`          | Developer headers (optional) |
          | `mysql-router.rpm`                   | Router (optional)            |


          rpm -qa | grep -i mariadb
          sudo dnf remove mariadb mariadb-server mariadb-libs -y
          rm -rf /var/lib/mysql
          rm -rf /etc/my.cnf*
          dnf install libaio numactl-libs perl wget openssl -y



          rpm -ivh mysql-community-common-8.0.40-1.el8.x86_64.rpm
          rpm -ivh mysql-community-libs-8.0.40-1.el8.x86_64.rpm
          rpm -ivh mysql-community-libs-compat-8.0.40-1.el8.x86_64.rpm
          rpm -ivh mysql-community-client-8.0.40-1.el8.x86_64.rpm
          rpm -ivh mysql-community-server-8.0.40-1.el8.x86_64.rpm
          rpm -ivh mysql-shell-8.0.40-1.el8.x86_64.rpm

          rpm -qa | grep -i mysql
          systemctl enable mysqld
          systemctl start mysqld
          systemctl status mysqld


          vi /etc/my.cnf
          
          [mysqld]
          datadir=/var/lib/mysql
          socket=/var/lib/mysql/mysql.sock
          symbolic-links=0
          log-error=/var/log/mysqld.log
          pid-file=/var/run/mysqld/mysqld.pid
          
          [client]
          socket=/var/lib/mysql/mysql.sock



          systemctl restart mysqld



##########################################################################################################


If using a non-default data directory:

          semanage fcontext -a -t mysqld_db_t "/data/mysql(/.*)?"
          restorecon -Rv /data/mysql

