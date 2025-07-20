#!/bin/bash

# Configuration
BACKUP_DIR="/opt/docmost-backups"
LOG_FILE="/var/log/docmost-backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_TYPE=${1:-daily}  # daily, weekly, manual

# Create backup directory
mkdir -p $BACKUP_DIR
mkdir -p $BACKUP_DIR/daily
mkdir -p $BACKUP_DIR/weekly
mkdir -p $BACKUP_DIR/monthly

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Function to send notification (optional)
send_notification() {
    # Uncomment if you want email notifications
    # echo "$1" | mail -s "Docmost Backup $2" admin@yourdomain.com
    log_message "$1"
}

log_message "🔄 Starting Docmost $BACKUP_TYPE backup"

# Check if containers are running
if ! docker compose ps | grep -q "Up"; then
    log_message "❌ Docmost containers are not running!"
    send_notification "Backup failed: Containers not running" "FAILED"
    exit 1
fi

# Set backup directory based on type
case $BACKUP_TYPE in
    "weekly")
        CURRENT_BACKUP_DIR="$BACKUP_DIR/weekly"
        RETENTION_DAYS=30
        ;;
    "monthly")
        CURRENT_BACKUP_DIR="$BACKUP_DIR/monthly"
        RETENTION_DAYS=365
        ;;
    *)
        CURRENT_BACKUP_DIR="$BACKUP_DIR/daily"
        RETENTION_DAYS=7
        ;;
esac

# Backup PostgreSQL database
log_message "💾 Backing up PostgreSQL database..."
if docker exec docmost-postgres pg_dump -U root -d docmost > $CURRENT_BACKUP_DIR/docmost_postgres_$DATE.sql; then
    log_message "✅ PostgreSQL backup completed"
else
    log_message "❌ PostgreSQL backup failed"
    send_notification "PostgreSQL backup failed" "FAILED"
    exit 1
fi

# Backup storage volume
log_message "📁 Backing up storage volume..."
if docker run --rm -v docmost_docmost_storage:/source -v $CURRENT_BACKUP_DIR:/backup alpine tar czf /backup/docmost_storage_$DATE.tar.gz -C /source .; then
    log_message "✅ Storage backup completed"
else
    log_message "❌ Storage backup failed"
fi

# Backup Redis data
log_message "🗃️  Backing up Redis data..."
if docker run --rm -v docmost_redis_data:/source -v $CURRENT_BACKUP_DIR:/backup alpine tar czf /backup/docmost_redis_$DATE.tar.gz -C /source .; then
    log_message "✅ Redis backup completed"
else
    log_message "❌ Redis backup failed"
fi

# Backup configuration
log_message "⚙️  Backing up configuration..."
if tar czf $CURRENT_BACKUP_DIR/docmost_config_$DATE.tar.gz docker-compose.yml .env nginx/; then
    log_message "✅ Configuration backup completed"
else
    log_message "❌ Configuration backup failed"
fi

# Calculate backup sizes
POSTGRES_SIZE=$(du -h $CURRENT_BACKUP_DIR/docmost_postgres_$DATE.sql | cut -f1)
STORAGE_SIZE=$(du -h $CURRENT_BACKUP_DIR/docmost_storage_$DATE.tar.gz | cut -f1)

log_message "📊 Backup sizes: PostgreSQL=$POSTGRES_SIZE, Storage=$STORAGE_SIZE"

# Clean old backups
log_message "🧹 Cleaning old backups (keeping $RETENTION_DAYS days)..."
find $CURRENT_BACKUP_DIR -name "docmost_*" -mtime +$RETENTION_DAYS -delete

# Generate backup report
TOTAL_BACKUPS=$(ls -1 $CURRENT_BACKUP_DIR/docmost_postgres_*.sql 2>/dev/null | wc -l)
DISK_USAGE=$(du -sh $BACKUP_DIR | cut -f1)

log_message "✅ Backup completed successfully"
log_message "📁 Total $BACKUP_TYPE backups: $TOTAL_BACKUPS"
log_message "💽 Total backup disk usage: $DISK_USAGE"

send_notification "Backup completed successfully. PostgreSQL: $POSTGRES_SIZE, Storage: $STORAGE_SIZE, Total backups: $TOTAL_BACKUPS" "SUCCESS"
