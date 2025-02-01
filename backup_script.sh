#!/bin/bash
# ------------------------------------------------------------------------------
# KVM VM Backup Script
# Author: Jan Skolnik
# ------------------------------------------------------------------------------
# This script performs backups of KVM virtual machines with features such as:
# - Excluding specific VMs
# - Excluding specific disks for individual VMs
# - Full support for retention rules
# - Email notifications for success or failure
#
# Configuration is separated from the main code for better readability.

# ------------------------------------------------------------------------------
# Configuration Section
# ------------------------------------------------------------------------------

# Path for storing backups
BACKUP_DIR=""
BACKUP_DIR_MOUNTPOINT=""

# Administrator email for notifications
ADMIN_EMAIL=""

# Send emails on successful backup? (true/false)
SEND_SUCCESS_EMAIL=true

# Check if the storage is mounted? (true/false)
CHECK_MOUNTED=true

# Retention rules:
RETENTION_DAYS=0                    # Number of days to keep backups
RETENTION_FULL_BACKUPS=4            # Number of full backups to retain

# Exclude specific VMs and disks:
EXCLUDE_VMS=""				# VM names separated by '|'
EXCLUDE_DISKS_BY_VM=""			# Syntax: vm_name:disk_name|vm_name:diskX

# Day of the week for full backup (7 = Sunday, 6 = Saturday)
FULL_BACKUP_DAY=6

# Maximum days between full backups
MAX_DAYS_BETWEEN_FULL_BACKUPS=7

# ------------------------------------------------------------------------------
# Script Section
# ------------------------------------------------------------------------------

# Check if the storage is mounted
if [ "$CHECK_MOUNTED" = true ]; then
  if ! mountpoint -q "$BACKUP_DIR_MOUNTPOINT"; then
    mount "$BACKUP_DIR_MOUNTPOINT"
    if ! mountpoint -q "$BACKUP_DIR_MOUNTPOINT"; then
      echo "Error: Unable to mount storage at $BACKUP_DIR!" | mail -s "Storage Error" "$ADMIN_EMAIL"
      exit 1
    fi
  fi
fi

# Initialize backup status for email reporting
BACKUP_STATUS=""

# Function to retrieve excluded disks for a specific VM
get_excluded_disks() {
  local vm_name="$1"
  # Parse the configuration string to find excluded disks for the given VM
  echo "$EXCLUDE_DISKS_BY_VM" | tr '|' '\n' | grep "^$vm_name:" | cut -d':' -f2 | tr ',' ' '
}

# Iterate through all VMs and perform backups
for DOMAIN in $(virsh list --name --all); do
  # Skip excluded VMs
  if [ -n "$EXCLUDE_VMS" ] && echo "$DOMAIN" | grep -q -E "${EXCLUDE_VMS}"; then
    continue
  fi

  # Retrieve excluded disks for the current VM
  EXCLUDED_DISKS=$(get_excluded_disks "$DOMAIN")

  # Read the date of the last full backup
  LAST_FULL_BACKUP=$(cat "$BACKUP_DIR/$DOMAIN/last_full_backup.txt" 2>/dev/null)
  CURRENT_DATE=$(date +%Y-%m-%d)

  # Initialize flag for full backup
  PERFORM_FULL_BACKUP=false

  # Check if last full backup exists
  if [ -n "$LAST_FULL_BACKUP" ]; then
    # Calculate days since last full backup
    DAYS_SINCE_LAST_FULL=$(( ($(date +%s) - $(date -d "$LAST_FULL_BACKUP" +%s)) / 86400 ))

    # Determine full backup logic
    if [ "$DAYS_SINCE_LAST_FULL" -ge "$MAX_DAYS_BETWEEN_FULL_BACKUPS" ]; then
      PERFORM_FULL_BACKUP=true
    elif [ $(date +%u) -eq "$FULL_BACKUP_DAY" ] && [ "$LAST_FULL_BACKUP" != "$CURRENT_DATE" ]; then
      PERFORM_FULL_BACKUP=true
    fi
  else
    # No previous full backup exists
    PERFORM_FULL_BACKUP=true
  fi

  # Perform full backup if conditions are met
  if [ "$PERFORM_FULL_BACKUP" = true ]; then
    mkdir -p "$BACKUP_DIR/$DOMAIN/$CURRENT_DATE"
    echo "$CURRENT_DATE" > "$BACKUP_DIR/$DOMAIN/last_full_backup.txt"
    LAST_FULL_BACKUP="$CURRENT_DATE"

    # Apply retention rules for full backups
    if [ "$RETENTION_FULL_BACKUPS" -ne 0 ]; then
      ls -dt "$BACKUP_DIR/$DOMAIN"/*/ | tail -n +$(($RETENTION_FULL_BACKUPS + 1)) | xargs rm -rf
    fi
  fi

  # Define log file for the current backup
  LOG_FILE="$BACKUP_DIR/$DOMAIN/$LAST_FULL_BACKUP/$CURRENT_DATE.log"

  # Perform backup, excluding specific disks if specified
  if [ -n "$EXCLUDED_DISKS" ]; then
    EXCLUDED_DISKS_ARGS=$(echo "$EXCLUDED_DISKS" | sed 's/^/--exclude /' | tr '\n' ' ')
    virtnbdbackup -d "$DOMAIN" -l auto -o "$BACKUP_DIR/$DOMAIN/$LAST_FULL_BACKUP" $EXCLUDED_DISKS_ARGS > "$LOG_FILE" 2>&1
  else
    virtnbdbackup -d "$DOMAIN" -l auto -o "$BACKUP_DIR/$DOMAIN/$LAST_FULL_BACKUP" > "$LOG_FILE" 2>&1
  fi

  # Check the result of the backup and update the status
  if [ $? -ne 0 ]; then
    BACKUP_STATUS+="Error: Backup of VM $DOMAIN failed!\n"
    mail -s "Backup Error for VM $DOMAIN" -a "$LOG_FILE" "$ADMIN_EMAIL" < "$LOG_FILE"
  else
    BACKUP_STATUS+="Success: Backup of VM $DOMAIN completed successfully.\n"
  fi

done

# Apply retention rules to all backups
for DOMAIN in $(virsh list --name --state-running); do
  if [ -n "$EXCLUDE_VMS" ] && echo "$DOMAIN" | grep -q -E "${EXCLUDE_VMS}"; then
    continue
  fi
  if [ "$RETENTION_DAYS" -ne 0 ]; then
    # Delete backups older than the retention period
    find "$BACKUP_DIR/$DOMAIN"/*/* -mindepth 1 -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} \;
  fi
done

# Send backup summary email
if [ "$SEND_SUCCESS_EMAIL" = true ] || [[ "$BACKUP_STATUS" == *"failed"* ]]; then
  echo -e "$BACKUP_STATUS" | mail -s "Backup Status" "$ADMIN_EMAIL"
fi

