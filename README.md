# WordPress Backup & Azure Upload Automation

A fully automated Bash script that:

- Creates WordPress backups using **All-in-One WP Migration** (`.wpress`)
- Zips them with password protection
- Uploads to **Azure Blob Storage**
- Manages backup retention (keeps only the latest 5 `.wpress` backups)
- Logs all actions with timestamps
- Runs via cron on Ubuntu servers

---

## Requirements

- Ubuntu 20.04+ server
- WordPress site with [All-in-One WP Migration](https://wordpress.org/plugins/all-in-one-wp-migration/)
- WP-CLI installed
- Azure CLI installed
- `zip` utility installed
- Enough free space in `/home/ubuntu/herlan_backup_zip` (~6–7 GB per backup)
- A user (e.g., `ubuntu`) with sudo privileges

---

## 1. Install Required Packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install curl unzip zip -y

# Install WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
wp --info

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az version

# Temporary zip directory
ZIP_DIR="/home/ubuntu/herlan_backup_zip"
mkdir -p "$ZIP_DIR"
chmod 755 "$ZIP_DIR"