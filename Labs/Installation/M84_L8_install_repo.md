# MySQL 8.4.x Installation Guide for Rocky Linux 8

## Prerequisites
- Rocky Linux 8 server with root or sudo access
- Internet connectivity
- At least 2GB of free disk space

---

## Step 1: Update System Packages

First, ensure your system is up to date:

```bash
sudo dnf update -y
```

**Note:** If the kernel is updated, reboot the system:
```bash
sudo reboot
```

---

## Step 2: Install MySQL 8.4 Repository

Rocky Linux 8's default AppStream repository only includes MySQL 8.0. To install MySQL 8.4.x, you need to add the official MySQL repository from Oracle.

### Download and Install the MySQL Yum Repository

```bash
sudo dnf install https://dev.mysql.com/get/mysql84-community-release-el8-1.noarch.rpm -y
```

This command:
- Downloads the MySQL 8.4 repository configuration package
- Installs it to `/etc/yum.repos.d/`
- Enables the MySQL 8.4 LTS Community repository by default
- Downloads the GnuPG key for package integrity verification

### Verify Repository Installation

Check that the MySQL repository was added successfully:

```bash
sudo dnf repolist enabled | grep mysql
```

Expected output should show something like:
```
mysql-8.4-lts-community          MySQL 8.4 LTS Community Server
mysql-connectors-community       MySQL Connectors Community
mysql-tools-8.4-lts-community    MySQL Tools 8.4 LTS Community
```

### Configure Repository to Use MySQL 8.4 LTS

**Important:** Ensure MySQL 8.0 repository is disabled and MySQL 8.4 LTS is enabled:

```bash
# Disable MySQL 8.0 repository (if enabled)
sudo dnf config-manager --disable mysql80-community

# Enable MySQL 8.4 LTS repository
sudo dnf config-manager --enable mysql-8.4-lts-community
```

**Note:** The `mysql84-community-release-el8-1.noarch.rpm` package should already enable the MySQL 8.4 LTS repository by default, but running these commands ensures the correct repository is active, especially if you had a previous MySQL repository configuration.

### Verify Correct Repository is Enabled

Check which MySQL subrepositories are enabled:

```bash
sudo dnf repolist all | grep mysql
```

Expected output:
```
mysql-8.4-lts-community          MySQL 8.4 LTS Community Server      enabled
mysql80-community                MySQL 8.0 Community Server          disabled
mysql-connectors-community       MySQL Connectors Community          enabled
mysql-tools-8.4-lts-community    MySQL Tools 8.4 LTS Community       enabled
```

Make sure `mysql-8.4-lts-community` shows **enabled** and `mysql80-community` shows **disabled**.

---

## Step 3: Install MySQL 8.4 Server

Now install the MySQL Community Server package:

```bash
sudo dnf install mysql-community-server -y
```

This will install:
- `mysql-community-server` (main server package)
- `mysql-community-client` (command-line client)
- `mysql-community-common` (common files)
- `mysql-community-libs` (shared libraries)
- `mysql-community-icu-data-files` (ICU data files)
- Various dependencies

**Note:** The installation will download approximately 50-60 MB of packages.

---

## Step 4: Start and Enable MySQL Service

### Start MySQL Service

```bash
sudo systemctl start mysqld
```

### Enable MySQL to Start on Boot

```bash
sudo systemctl enable mysqld
```

### Verify MySQL is Running

```bash
sudo systemctl status mysqld
```

Expected output:
```
● mysqld.service - MySQL Server
   Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
   Active: active (running) since [timestamp]
   ...
   Status: "Server is operational"
```

---

## Step 5: Retrieve Temporary Root Password

MySQL 8.4 generates a temporary password for the root user during installation. Retrieve it:

```bash
sudo grep 'A temporary password is generated' /var/log/mysqld.log | tail -1
```

**Example output:**
```
2025-02-01T10:30:15.123456Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: Xy7k#pL9mN2q
```

**Copy the password** (in this example: `Xy7k#pL9mN2q`) — you'll need it in the next step.

---

## Step 6: Secure MySQL Installation

Run the security script to harden your MySQL installation:

```bash
sudo mysql_secure_installation
```

### Interactive Prompts:

1. **Enter password for user root:**
   - Paste the temporary password from Step 5

2. **New password:**
   - Enter a strong new password
   - Re-enter to confirm

3. **The 'validate_password' component is installed...**
   - Password strength will be displayed (e.g., "Estimated strength of the password: 100")
   - **Change the password for root?** → Type `N` (you just set it)

4. **Remove anonymous users?** → Type `Y`
   - Removes test users without passwords

5. **Disallow root login remotely?** → Type `Y`
   - Prevents root login from network (recommended for security)

6. **Remove test database and access to it?** → Type `Y`
   - Removes the default test database

7. **Reload privilege tables now?** → Type `Y`
   - Applies all security changes immediately

---

## Step 7: Test MySQL Installation

### Login to MySQL

```bash
mysql -u root -p
```

Enter the root password you set in Step 6.

### Verify MySQL Version

Once logged in, check the version:

```sql
SELECT VERSION();
```

Expected output:
```
+-----------+
| VERSION() |
+-----------+
| 8.4.x     |
+-----------+
```

### Show Databases

```sql
SHOW DATABASES;
```

Expected output:
```
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
```

### Exit MySQL

```sql
EXIT;
```

or simply:

```sql
\q
```

---

## Step 8: Configure Firewall (Optional but Recommended)

If you need to allow remote connections to MySQL (only do this if absolutely necessary):

```bash
# Allow MySQL through firewall
sudo firewall-cmd --permanent --add-service=mysql

# Reload firewall
sudo firewall-cmd --reload
```

**Security Note:** Only open the MySQL port if you need remote access. Always use strong passwords and consider using SSH tunneling instead.

---

## Step 9: Create a Database and User (Optional)

### Login to MySQL

```bash
mysql -u root -p
```

### Create a New Database

```sql
CREATE DATABASE myapp_db;
```

### Create a New User and Grant Privileges

```sql
-- Create user (replace 'myuser' and 'strong_password')
CREATE USER 'myuser'@'localhost' IDENTIFIED BY 'strong_password';

-- Grant all privileges on the database
GRANT ALL PRIVILEGES ON myapp_db.* TO 'myuser'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;
```

### Verify User and Database

```sql
-- Show all users
SELECT user, host FROM mysql.user;

-- Show databases
SHOW DATABASES;

-- Exit
EXIT;
```

### Test New User Login

```bash
mysql -u myuser -p myapp_db
```

---

## Useful MySQL Service Management Commands

```bash
# Start MySQL
sudo systemctl start mysqld

# Stop MySQL
sudo systemctl stop mysqld

# Restart MySQL
sudo systemctl restart mysqld

# Check status
sudo systemctl status mysqld

# Enable on boot
sudo systemctl enable mysqld

# Disable on boot
sudo systemctl disable mysqld

# View MySQL logs
sudo journalctl -u mysqld -f
```

---

## Important Configuration Files

- **Main config:** `/etc/my.cnf`
- **Data directory:** `/var/lib/mysql/`
- **Log file:** `/var/log/mysqld.log`
- **Socket:** `/var/lib/mysql/mysql.sock`
- **Repository config:** `/etc/yum.repos.d/mysql-community.repo`

---

## Troubleshooting

### MySQL Won't Start

Check logs for errors:
```bash
sudo journalctl -u mysqld -n 50
# or
sudo tail -50 /var/log/mysqld.log
```

### Forgot Root Password

If you forget the root password, you can reset it:

1. Stop MySQL:
   ```bash
   sudo systemctl stop mysqld
   ```

2. Start MySQL in safe mode:
   ```bash
   sudo mysqld_safe --skip-grant-tables &
   ```

3. Login without password:
   ```bash
   mysql -u root
   ```

4. Reset password:
   ```sql
   FLUSH PRIVILEGES;
   ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';
   EXIT;
   ```

5. Kill safe mode and restart normally:
   ```bash
   sudo pkill mysqld
   sudo systemctl start mysqld
   ```

### Check MySQL Error Log

```bash
sudo less /var/log/mysqld.log
```

---

## Post-Installation Recommendations

1. **Regular Backups:** Set up automated backups using `mysqldump` or MySQL Enterprise Backup
2. **Monitoring:** Consider installing monitoring tools like Percona Monitoring and Management (PMM)
3. **Performance Tuning:** Review and adjust `/etc/my.cnf` based on your workload
4. **Security Updates:** Regularly update MySQL: `sudo dnf update mysql-community-server`
5. **User Management:** Follow the principle of least privilege when creating database users

---

## Verification Checklist

- [ ] MySQL 8.4.x is installed
- [ ] MySQL service is running
- [ ] MySQL starts automatically on boot
- [ ] Root password is set and secure
- [ ] Anonymous users are removed
- [ ] Remote root login is disabled
- [ ] Test database is removed
- [ ] You can log in with the root account
- [ ] (Optional) Firewall configured if remote access needed
- [ ] (Optional) Application database and user created

---

## Additional Resources

- **Official MySQL 8.4 Documentation:** https://dev.mysql.com/doc/refman/8.4/en/
- **MySQL Security Guide:** https://dev.mysql.com/doc/refman/8.4/en/security.html
- **Performance Tuning:** https://dev.mysql.com/doc/refman/8.4/en/optimization.html
- **Backup and Recovery:** https://dev.mysql.com/doc/refman/8.4/en/backup-and-recovery.html

---

**Installation Complete!** 🎉

Your MySQL 8.4.x server is now installed and secured on Rocky Linux 8.
