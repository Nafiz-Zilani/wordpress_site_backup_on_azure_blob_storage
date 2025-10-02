#!/bin/bash
# WordPress backup + Azure upload script with zip and retention

# === Config ===
WP_BACKUP_DIR="/var/www/html/herlan_main/wp-content/ai1wm-backups" # Adjust if needed
ZIP_DIR="/home/ubuntu/herlan_backup_zip" # Temporary zip storage. Adjust if needed
STORAGE_ACCOUNT="Yous STORAGE_ACCOUNT"
STORAGE_KEY="Your STORAGE_KEY"
CONTAINER_NAME="Your CONTAINER_NAME"
ZIP_PASSWORD="Give a strong password for the zip file"
MAX_BACKUPS=5 # Number of backups to keep locally adjust based on your needs

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

# === Step 3: Zip backup in safe folder ===
mkdir -p "$ZIP_DIR"
ZIP_FILE="$ZIP_DIR/$(basename "${LATEST_BACKUP%.wpress}")-$TIMESTAMP.zip"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Zipping backup to $ZIP_FILE ..."
zip -P "$ZIP_PASSWORD" "$ZIP_FILE" "$LATEST_BACKUP"
if [ $? -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Zipping failed ❌"
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

# === Step 5: Delete temporary zip ===
rm -f "$ZIP_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Temporary zip file deleted."

# === Step 6: Cleanup old backups (keep latest 5) ===
echo "$(date '+%Y-%m-%d %H:%M:%S') - Cleaning up old backups, keeping only the latest $MAX_BACKUPS..."
cd "$WP_BACKUP_DIR"
sudo ls -tp *.wpress | grep -v '/$' | tail -n +$((MAX_BACKUPS+1)) | xargs -I {} sudo rm -- {}
echo "$(date '+%Y-%m-%d %H:%M:%S') - Cleanup complete."
