#!/bin/bash

BACKUP_DIR="/opt/docmost-backups"
BACKUP_TYPE=${1:-daily}
BACKUP_DATE=$2

if [ -z "$BACKUP_DATE" ]; then
    echo "Usage: $0 [daily|weekly|monthly] YYYYMMDD_HHMMSS"
    echo "Available backups:"
    ls -la $BACKUP_DIR/$BACKUP_TYPE/docmost_postgres_*.sql 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$BACKUP_DIR/$BACKUP_TYPE/docmost_postgres_$BACKUP_DATE.sql"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "⚠️  WARNING: This will replace current database with backup from $BACKUP_DATE"
read -p "Are you sure? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled"
    exit 1
fi

echo "🔄 Stopping Docmost application..."
docker compose stop docmost

echo "🗃️  Restoring PostgreSQL database..."
docker exec -i docmost-postgres psql -U docmost_user -d docmost < $BACKUP_FILE

echo "🔄 Starting Docmost application..."
docker compose start docmost

echo "✅ Restore completed!"
