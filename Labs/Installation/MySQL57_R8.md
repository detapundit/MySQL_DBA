      ### Complete Installation Summary

      Step 1:  sudo dnf update -y
      Step 2:  sudo dnf module disable mysql mariadb -y
      Step 3:  Create /etc/yum.repos.d/mysql57-community.repo  (EL7 baseurl)
      Step 4:  sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql
               sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
      Step 5:  sudo dnf install -y ncurses-compat-libs
      Step 6:  sudo dnf makecache
      Step 7:  sudo dnf install -y mysql-community-server mysql-community-client \
                                   mysql-community-common mysql-community-libs \
                                   mysql-community-libs-compat
      Step 8:  mysqld --version           → verify 5.7.44
      Step 9:  sudo systemctl enable --now mysqld
      Step 10: sudo grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}'
      Step 11: sudo mysql_secure_installation
      Step 12: mysql -u root -p → SELECT VERSION();
      Step 13: Edit /etc/my.cnf → sudo systemctl restart mysqld
