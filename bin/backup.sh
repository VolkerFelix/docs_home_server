#!/bin/bash

# =============================================================================
# Configuration - Edit these variables according to your setup
# =============================================================================

# Application directory
DOCS_DIR="/home/volker/work/docs_home_server"

# Backup storage
BACKUP_BASE="/home/volker/backups/areum-docs"
RETENTION_DAYS=30

# Remote backup (optional)
REMOTE_BACKUP="false"
REMOTE_USER="volker"
REMOTE_HOST="backup-server"
REMOTE_PATH="/backup/docs"

# Email notifications (optional)
ENABLE_NOTIFICATIONS="true"
ADMIN_EMAIL="volker.leukhardt@gmail.com"

# Encryption (optional)
ENABLE_ENCRYPTION="false"
GPG_RECIPIENT="volker.leukhardt@gmail.com"

# =============================================================================
# Script Logic - Don't modify unless you know what you're doing
# =============================================================================

# Initialize logging
LOG_FILE="$BACKUP_BASE/backup.log"
mkdir -p "$BACKUP_BASE"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $1"
    if [ "$ENABLE_NOTIFICATIONS" = "true" ]; then
        echo "Backup failed: $1" | mail -s "Docs Backup FAILED" "$ADMIN_EMAIL"
    fi
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
fi

# Create backup directory
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE/$BACKUP_DATE"
mkdir -p "$BACKUP_DIR" || error "Failed to create backup directory"

# Change to docs directory
cd "$DOCS_DIR" || error "Failed to change to docs directory"

log "Starting backup process..."

# Stop services
log "Stopping services..."
make stop-production || error "Failed to stop services"

# Backup function
backup_with_retry() {
    local source=$1
    local dest=$2
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log "Backing up $source (attempt $attempt)"
        if tar czf "$dest" "$source"; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 5
    done
    return 1
}

# Perform backups
log "Backing up databases..."
backup_with_retry "data/production/databases" "$BACKUP_DIR/databases.tar.gz" || error "Failed to backup databases"

log "Backing up media..."
backup_with_retry "data/production/media" "$BACKUP_DIR/media.tar.gz" || error "Failed to backup media"

log "Backing up configuration..."
backup_with_retry "env.d/production" "$BACKUP_DIR/env.tar.gz" || error "Failed to backup configuration"

log "Backing up SSL certificates..."
backup_with_retry "/etc/letsencrypt" "$BACKUP_DIR/letsencrypt.tar.gz" || error "Failed to backup SSL certificates"

# Encrypt sensitive files if enabled
if [ "$ENABLE_ENCRYPTION" = "true" ]; then
    log "Encrypting sensitive files..."
    for file in "$BACKUP_DIR/env.tar.gz" "$BACKUP_DIR/letsencrypt.tar.gz"; do
        gpg --encrypt --recipient "$GPG_RECIPIENT" "$file" || error "Failed to encrypt $file"
        rm "$file"  # Remove unencrypted file
    done
fi

# Restart services
log "Restarting services..."
make deploy || error "Failed to restart services"

# Remote backup if enabled
if [ "$REMOTE_BACKUP" = "true" ]; then
    log "Copying backup to remote server..."
    rsync -az --delete "$BACKUP_DIR" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" || error "Failed to copy backup to remote server"
fi

# Cleanup old backups
log "Cleaning up old backups..."
find "$BACKUP_BASE" -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} \;

# If we got here, backup was successful
log "Backup completed successfully!"

if [ "$ENABLE_NOTIFICATIONS" = "true" ]; then
    # Send success notification with backup size
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    echo "Backup completed successfully. Backup size: $BACKUP_SIZE" | \
        mail -s "Docs Backup Successful" "$ADMIN_EMAIL"
fi 