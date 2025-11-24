
MySQL 8 Binary Installation Steps for Rocky Linux 8

1. Download MySQL Binary Tarball

          cd /opt 
          wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.40-el8-x86_64.tar.gz

2. Extract the Tarball

          tar -xzf mysql-8.0.40-el8-x86_64.tar.gz 
          mv mysql-8.0.40-el8-x86_64 mysql

3. Create MySQL User and Group

          groupadd mysql 
          useradd -r -g mysql -s /bin/false mysql

4. Create Data Directory

          mkdir /data/mysql 
          chown -R mysql:mysql /data/mysql 
          chmod 750 /data/mysql

5. Initialize MySQL Database

          cd /opt/mysql 
          bin/mysqld –initialize –user=mysql –basedir=/opt/mysql –datadir=/data/mysql

Check temporary password: grep ‘temporary password’


          grep 'temporary password' /data/mysql/mysqld.log


6. Create /etc/my.cnf

          [client] 
          port=3306
          socket=/var/lib/mysql/mysql.sock
          
          [mysqld]
          user=mysql
          basedir=/opt/mysql
          datadir=/data/mysql
          port=3306
          socket=/var/lib/mysql/mysql.sock
          pid-file=/var/run/mysqld/mysqld.pid
          log-error=/var/log/mysql/error.log
          secure-file-priv=/var/lib/mysql-files
          symbolic-links=0
          bind-address=0.0.0.0

7. Create required directories

          mkdir -p /var/lib/mysql /var/log/mysql /varlib/mysql-files 
          chown -R mysql:mysql /var/lib/mysql /var/log/mysql /var/lib/mysql-files

8. Add MySQL to PATH

          echo ‘export PATH=/opt/mysql/bin:$PATH’ > /etc/profile.d/mysql.sh
          chmod +x /etc/profile.d/mysql.sh
          source /etc/profile.d/mysql.sh

9. Create systemd Service File

          /etc/systemd/system/mysqld.service:

          [Unit]
          Description=MySQL Server After=network.target
          
          [Service]
          User=mysql
          Group=mysql
          ExecStart=/opt/mysql/bin/mysqld –defaults-file=/etc/my.cnf
          LimitNOFILE=50000
          
          [Install]
          WantedBy=multi-user.target


Reload systemd: 

          systemctl daemon-reload

10. Start MySQL Service

          systemctl start mysqld 
          systemctl enable mysqld

11. Secure MySQL Installation

          mysql -u root -p ALTER USER ‘root’@‘localhost’ IDENTIFIED BY
          ‘StrongPassword@123’; 
          mysql_secure_installation

12. Verify Installation

          mysql –version
