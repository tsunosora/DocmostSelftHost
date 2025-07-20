#!/bin/bash

BACKUP_DIR="/opt/docmost-backups"
LOG_FILE="/var/log/docmost-backup.log"

echo "=== Docmost Backup Status ==="
echo "Date: $(date)"
echo

# Check last backup
LAST_DAILY=$(ls -t $BACKUP_DIR/daily/docmost_postgres_*.sql 2>/dev/null | head -1)
LAST_WEEKLY=$(ls -t $BACKUP_DIR/weekly/docmost_postgres_*.sql 2>/dev/null | head -1)

if [ -n "$LAST_DAILY" ]; then
    DAILY_DATE=$(stat -c %y "$LAST_DAILY" | cut -d' ' -f1,2)
    DAILY_SIZE=$(du -h "$LAST_DAILY" | cut -f1)
    echo "✅ Last daily backup: $DAILY_DATE ($DAILY_SIZE)"
else
    echo "❌ No daily backups found"
fi

if [ -n "$LAST_WEEKLY" ]; then
    WEEKLY_DATE=$(stat -c %y "$LAST_WEEKLY" | cut -d' ' -f1,2)
    WEEKLY_SIZE=$(du -h "$LAST_WEEKLY" | cut -f1)
    echo "✅ Last weekly backup: $WEEKLY_DATE ($WEEKLY_SIZE)"
else
    echo "❌ No weekly backups found"
fi

# Check backup directory sizes
echo
echo "=== Backup Directory Sizes ==="
du -sh $BACKUP_DIR/*/

# Check recent backup logs
echo
echo "=== Recent Backup Logs ==="
tail -20 $LOG_FILE 2>/dev/null || echo "No backup logs found"

# Check cron jobs
echo
echo "=== Backup Cron Jobs ==="
crontab -l | grep docmost || echo "No backup cron jobs found"
