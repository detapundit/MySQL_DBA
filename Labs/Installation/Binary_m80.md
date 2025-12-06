
MySQL 8 Binary Installation Steps for Rocky Linux 8


                              cd /tmp
                              yum install libaio wget
                              wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.44-linux-glibc2.28-x86_64.tar.xz
                              cd /usr/local/
                              tar -xJf /tmp/mysql-8.0.44-linux-glibc2.28-x86_64.tar.xz 
                              ls -lt
                              mv mysql-8.0.44-linux-glibc2.28-x86_64 mysql
                              
                              groupadd mysql
                              useradd -r -g mysql -s /bin/false mysql
                              mkdir -p /usr/local/mysql/data
                              chown -R mysql:mysql /usr/local/mysql
                              chmod -R 750 /usr/local/mysql
                              mkdir -p /usr/local/mysql/mysql-files
                              chown -R mysql:mysql /usr/local/mysql/mysql-files
                              cd /usr/local/mysql
                              mkdir -p /var/run/mysqld /var/log
                              touch /var/log/mysqld.log
                              chown -R mysql:mysql /var/run/mysqld
                              chown mysql:mysql /var/log/mysqld.log
                              
                              sudo bin/mysqld --initialize --user=mysql --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data
                              vi /etc/my.cnf
                              
                              #############
                              [mysqld]
                              basedir = /usr/local/mysql
                              datadir = /usr/local/mysql/data
                              socket = /var/run/mysqld/mysqld.sock
                              pid-file = /var/run/mysqld/mysqld.pid
                              log-error = /var/log/mysqld.log
                              port = 3306
                              user = mysql
                              skip-symbolic-links = 0
                              secure_file_priv = /usr/local/mysql/mysql-files
                              ###################################
                              
                              
                              dnf install policycoreutils-python-utils -y
                              semanage fcontext -a -t mysqld_db_t "/usr/local/mysql/data(/.*)?"
                              semanage fcontext -a -t mysqld_log_t "/var/log/mysqld.log"
                              semanage fcontext -a -t mysqld_var_run_t "/var/run/mysqld(/.*)?"
                              restorecon -Rv /usr/local/mysql/data /var/log/mysqld.log /var/run/mysqld
                              semanage fcontext -a -t mysqld_log_t "/var/log/mysqld.log"
                              semanage fcontext -a -t mysqld_var_run_t "/var/run/mysqld(/.*)?"
                              restorecon -Rv /usr/local/mysql/data /var/log/mysqld.log /var/run/mysqld
                              echo 'export PATH=/usr/local/mysql/bin:$PATH' | sudo tee /etc/profile.d/mysql.sh
                              chmod +x /etc/profile.d/mysql.sh
                              source /etc/profile.d/mysql.sh
                              vi /etc/systemd/system/mysqld.service
                              
                              ############
                              
                              [Unit]
                              Description=MySQL Server
                              After=network.target
                              
                              [Service]
                              User=mysql
                              Group=mysql
                              LimitNOFILE=50000
                              ExecStart=/usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf
                              ExecStop=/usr/local/mysql/bin/mysqladmin shutdown
                              PIDFile=/var/run/mysqld/mysqld.pid
                              Restart=on-failure
                              
                              [Install]
                              WantedBy=multi-user.target
                              
                              ############
                              systemctl daemon-reload
                              ystemctl enable mysqld
                              systemctl enable mysqld
                              systemctl start mysqld
                              ps -ef|grep mysql
                              systemctl status mysqld -l
                              ls -lZ /usr/local/mysql/data
                              ls -lZ /var/log/mysqld.log
                              ls -ldZ /var/run/mysqld
                              
                              systemctl start mysqld
                              ps -ef|grep mysql
                              
                              mysql -uroot -p --socket=/var/run/mysqld/mysqld.sock



######################################################################################################################################

