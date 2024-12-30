#!/bin/bash

# Configurations
LOCAL_DB_HOST="localhost"
LOCAL_DB_USER="root"
LOCAL_DB_PASS="root"
LOCAL_DB_NAME="local"

DEV_DB_HOST="127.0.0.1:3306"
DEV_DB_USER="sonalidev"
DEV_DB_PASS="6JNxO-A3eut-jZY5HyKA"
DEV_DB_NAME="wp_sonalidev"


REMOTE_UPLOADS_PATH="/nas/content/live/sonalidev/wp-content/uploads"
LOCAL_UPLOADS_PATH="Users/gauri/Local Sites/github-setup/app/public/wp-content/uploads"

# Function to migrate database changes
migrate_db_changes() {
  SOURCE_DB_HOST=$1
  SOURCE_DB_USER=$2
  SOURCE_DB_PASS=$3
  SOURCE_DB_NAME=$4
  TARGET_DB_HOST=$5
  TARGET_DB_USER=$6
  TARGET_DB_PASS=$7
  TARGET_DB_NAME=$8

  echo "Exporting recent database changes from $SOURCE_DB_NAME..."
  RECENT_DB_FILE="recent_changes.sql"
  mysqldump -h $SOURCE_DB_HOST -u $SOURCE_DB_USER -p$SOURCE_DB_PASS $SOURCE_DB_NAME \
    --tables wp_posts wp_postmeta wp_users wp_usermeta \
    --where="post_modified >= NOW() - INTERVAL 2 HOUR" > $RECENT_DB_FILE

  if [[ $? -ne 0 ]]; then
      echo "Error: Database export failed!"
      exit 1
  fi

  echo "Importing database changes into $TARGET_DB_NAME..."
  mysql -h $TARGET_DB_HOST -u $TARGET_DB_USER -p$TARGET_DB_PASS $TARGET_DB_NAME < $RECENT_DB_FILE

  if [[ $? -ne 0 ]]; then
      echo "Error: Database import failed!"
      exit 1
  fi

  rm $RECENT_DB_FILE
  echo "Database changes migrated successfully!"
}

# Function to sync media files
sync_media_files() {
  echo "Syncing recent media files..."
  rsync -avz --include '*/' --include '*.jpg' --include '*.png' --include '*.gif' \
      --exclude '*' --modify-window=1 --prune-empty-dirs \
      --files-from=<(find $LOCAL_UPLOADS_PATH -type f -mmin -120 -print) $LOCAL_UPLOADS_PATH $REMOTE_UPLOADS_PATH

  if [[ $? -ne 0 ]]; then
      echo "Error: Media sync failed!"
      exit 1
  fi
  echo "Media files synced successfully!"
}

# Step 1: Move DB changes from Local to Dev
echo "Migrating from Local to Dev..."
migrate_db_changes $LOCAL_DB_HOST $LOCAL_DB_USER $LOCAL_DB_PASS $LOCAL_DB_NAME \
                   $DEV_DB_HOST $DEV_DB_USER $DEV_DB_PASS $DEV_DB_NAME

sync_media_files


echo "Migration from Local to Dev to Staging completed successfully!"
