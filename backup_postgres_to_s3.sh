#!/bin/bash

# PostgreSQL database credentials
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"
DB_HOST="${DB_HOST}"


# S3 bucket details
S3_BUCKET="${S3_BUCKET}"
S3_PATH="database_backups/postgresql"

# Backup directory
BACKUP_DIR="/tmp/db_backups"
mkdir -p $BACKUP_DIR

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/postgres_backup_$TIMESTAMP.sql"
COMPRESSED_BACKUP_FILE="$BACKUP_FILE.tar.gz"

echo "Starting PostgreSQL backup..."

# Create PostgreSQL dump
PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME --no-privileges --no-owner -f $BACKUP_FILE

# Check if backup was successful
if [ $? -eq 0 ]; then
  echo "PostgreSQL backup created successfully: $BACKUP_FILE"
  
  # Compress the backup file
  tar -czf $COMPRESSED_BACKUP_FILE $BACKUP_FILE
  echo "Backup compressed: $COMPRESSED_BACKUP_FILE"
  
  # Upload to S3
  echo "Uploading to S3..."
  aws s3 cp $COMPRESSED_BACKUP_FILE s3://$S3_BUCKET/$S3_PATH/postgres_backup_$TIMESTAMP.tar.gz
  
  # Check if upload was successful
  if [ $? -eq 0 ]; then
    echo "Backup uploaded to S3 successfully."
  else
    echo "Error: Failed to upload backup to S3."
  fi
  
  # Clean up local backup files
  rm $BACKUP_FILE $COMPRESSED_BACKUP_FILE
  echo "Local backup files cleaned up."
else
  echo "Error: PostgreSQL backup failed."
fi
