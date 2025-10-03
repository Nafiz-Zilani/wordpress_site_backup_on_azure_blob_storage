#!/bin/bash
# WordPress backup + Azure upload script with AES-256 encryption (7z) and retention

# === Config ===
WP_BACKUP_DIR="give your wordpress site directory/wp-content/ai1wm-backups"
ZIP_DIR="/home/ubuntu/herlan_backup_zip"
STORAGE_ACCOUNT="Azure Blob Storage account name"
STORAGE_KEY="Azure Blob Storage account key"
CONTAINER_NAME="Azure Blob Storage container name"
ZIP_PASSWORD="your-strong-password"
MAX_BACKUPS=5 # Number of backups to keep locally

# === Step 0: Timestamp ===
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REMOTE_FOLDER="herlan_ecommerce_backup/$TIMESTAMP"

# === Step 1: Create WordPress backup ===
echo "$(date '+%Y-%m-%d %H:%M:%S') - Creating WordPress backup..."
sudo wp --path=/var/www/html/herlan_main ai1wm backup --allow-root
if [ $? -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup failed ❌"
  exit 1
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup complete."

# === Step 2: Find latest backup file ===
LATEST_BACKUP=$(ls -t "$WP_BACKUP_DIR"/*.wpress | head -1)
if [ -z "$LATEST_BACKUP" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - No backup file found!"
  exit 1
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') - Latest backup file: $LATEST_BACKUP"

# === Step 3: Encrypt backup with 7z AES-256 ===
mkdir -p "$ZIP_DIR"
ZIP_FILE="$ZIP_DIR/$(basename "${LATEST_BACKUP%.wpress}")-$TIMESTAMP.7z"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Encrypting backup to $ZIP_FILE ..."
7z a -t7z -p"$ZIP_PASSWORD" -mhe=on "$ZIP_FILE" "$LATEST_BACKUP"
if [ $? -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Encryption failed ❌"
  exit 1
fi

# === Step 4: Upload to Azure ===
BLOB_NAME="$REMOTE_FOLDER/$(basename "$ZIP_FILE")"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Uploading $ZIP_FILE to Azure Blob Storage as $BLOB_NAME..."
/usr/bin/az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --container-name "$CONTAINER_NAME" \
  --name "$BLOB_NAME" \
  --file "$ZIP_FILE" \
  --overwrite true

if [ $? -eq 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup uploaded successfully ✅"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup upload failed ❌"
  rm -f "$ZIP_FILE"
  exit 1
fi

# === Step 5: Delete temporary encrypted file ===
rm -f "$ZIP_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Temporary encrypted backup deleted."

# === Step 6: Cleanup old backups (keep latest 5 only) ===
echo "$(date '+%Y-%m-%d %H:%M:%S') - Cleaning up old backups, keeping only the latest $MAX_BACKUPS..."
cd "$WP_BACKUP_DIR"
sudo ls -tp *.wpress | grep -v '/$' | tail -n +$((MAX_BACKUPS+1)) | xargs -I {} sudo rm -- {}
echo "$(date '+%Y-%m-%d %H:%M:%S') - Cleanup complete."