#!/bin/bash

# PostgreSQL database credentials
DB_NAME="mydatabase"
DB_USER="backupuser"
DB_PASSWORD="1234"
DB_HOST="54.82.27.95"

# S3 bucket details
S3_BUCKET="postgres-backup-hamza"
S3_PATH="database_backups/postgresql"

# Temporary directory for restoration
RESTORE_DIR="/tmp/db_restore"
mkdir -p $RESTORE_DIR

echo "Finding latest backup in S3..."

# Get the latest backup file from S3
LATEST_BACKUP=$(aws s3 ls s3://$S3_BUCKET/$S3_PATH/ | sort | tail -n 1 | awk '{print $4}')

if [ -z "$LATEST_BACKUP" ]; then
  echo "Error: No backup files found in S3."
  exit 1
fi

echo "Latest backup found: $LATEST_BACKUP"

# Download the latest backup
echo "Downloading backup from S3..."
aws s3 cp s3://$S3_BUCKET/$S3_PATH/$LATEST_BACKUP $RESTORE_DIR/$LATEST_BACKUP

# Extract the compressed backup
echo "Extracting backup..."
tar -xzf $RESTORE_DIR/$LATEST_BACKUP -C $RESTORE_DIR
EXTRACTED_SQL=$(find $RESTORE_DIR -name "*.sql" | head -n 1)

if [ -z "$EXTRACTED_SQL" ]; then
  echo "Error: Could not find SQL file in the extracted backup."
  exit 1
fi

# Restore the database
echo "Restoring PostgreSQL database..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f $EXTRACTED_SQL

# Check if restore was successful
if [ $? -eq 0 ]; then
  echo "PostgreSQL database restored successfully."
else
  echo "Error: Failed to restore PostgreSQL database."
  exit 1
fi

# Clean up
echo "Cleaning up temporary files..."
rm -rf $RESTORE_DIR
echo "Restore process completed."
