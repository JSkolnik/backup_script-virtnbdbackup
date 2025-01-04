# Backup script for Virtnbdbackup

## Overview
This script automates the backup process for KVM virtual machines (VMs). It includes features such as:  
- **Full and incremental backups** with configurable retention policies.  
- **Exclusion of specific VMs and disks** from the backup process.  
- **Email notifications** to the administrator about the success or failure of backups.  
- Automatic mounting of backup storage if required.  

Designed for easy customization and separation of configuration and logic, this script simplifies VM backup management for KVM environments.

---

## Features
- **Full and Incremental Backups**: Automates backup scheduling with configurable days for full backups.  
- **Retention Policies**: Controls how many full backups and/or how many days of backups to retain.  
- **Disk and VM Exclusions**: Allows exclusion of specific disks or entire VMs from backups.  
- **Email Notifications**: Sends notifications for backup successes or failures.  
- **Storage Check**: Verifies that the backup storage is mounted before proceeding.  

---

## Requirements
### Software
1. **Linux OS** with KVM/QEMU installed.  
2. **Virsh**: Command-line tool to interact with VMs.  
3. **virtnbdbackup**: Required for creating backups. Install using your package manager or build it from source.  
4. **Mail Utility**: Used to send email notifications (e.g., `mail` command from `mailx` or `sendmail`).  

### Permissions
- The script must be run with sufficient privileges to interact with `virsh` and access the backup directory.  

### Backup Storage
- A mounted storage directory for backups, specified in the configuration (`BACKUP_DIR`).  

---

## Configuration
Before running the script, adjust the following variables in the **Configuration Section**:
- **`BACKUP_DIR`**: Path where backups will be stored.  
- **`ADMIN_EMAIL`**: Email address for notifications.  
- **`SEND_SUCCESS_EMAIL`**: Whether to send email notifications for successful backups (`true` or `false`).  
- **`EXCLUDE_VMS`**: Names of VMs to exclude, separated by `|`.  
- **`EXCLUDE_DISKS_BY_VM`**: Specify disks to exclude in the format `vm_name:disk_name|vm_name:diskX`.  
- **`RETENTION_DAYS`**: Number of days to retain backups.  
- **`RETENTION_FULL_BACKUPS`**: Number of full backups to retain.  
- **`FULL_BACKUP_DAY`**: Day of the week for full backups (1 = Sunday, 7 = Saturday).
