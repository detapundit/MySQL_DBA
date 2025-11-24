
  1. Take MySQL Backups
       

          mysqldump -u root -p --all-databases --single-transaction --routines --events > /backup/all_db_backup.sql

  2. Get Current MySQL Configuration


          cp -r /etc/my.cnf /etc/my.cnf.bak
          cp -r /etc/mysql /etc/mysql.bak 2>/dev/null


3. Stop MySQL Service


sudo systemctl stop mysqld
sudo systemctl disable mysqld


✅ STEP 1 — Remove All MySQL Packages
rpm -qa | grep -i mysql
sudo dnf remove mysql* mysql80-community-release
sudo dnf remove mysql-router* mysql-shell* mysql-community*


✅ STEP 2 — Remove MySQL Data Directory

sudo rm -rf /var/lib/mysql
sudo rm -rf /var/lib/mysql-files
sudo rm -rf /var/lib/mysql-keyring

✅ STEP 3 — Remove MySQL Configuration Files

sudo rm -f /etc/my.cnf
sudo rm -rf /etc/mysql


sudo rm -f /usr/lib/systemd/system/mysqld.service


✅ STEP 4 — Remove MySQL User & Group (Optional)

sudo userdel mysql 2>/dev/null
sudo groupdel mysql 2>/dev/null

✅ STEP 5 — Remove MySQL Repo
dnf repolist

sudo rm -f /etc/yum.repos.d/mysql-community*.repo


✅ STEP 6 — Clean DNF Cache
sudo dnf clean all
sudo dnf makecache

🔍 VERIFY REMOVAL
rpm -qa | grep -i mysql


