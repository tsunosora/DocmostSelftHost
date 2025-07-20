#!/bin/bash

echo "=== Docmost PostgreSQL Monitoring ==="
echo "Date: $(date)"
echo

echo "=== Container Status ==="
docker compose ps
echo

echo "=== PostgreSQL Status ==="
docker exec docmost-postgres pg_isready -U docmost_user -d docmost
echo

echo "=== Database Size ==="
docker exec docmost-postgres psql -U docmost_user -d docmost -c "SELECT pg_size_pretty(pg_database_size('docmost')) as size;"
echo

echo "=== Application Health ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://192.168.1.33:3333/health
echo

echo "=== Resource Usage ==="
docker stats --no-stream docmost-app docmost-postgres docmost-redis docmost-nginx
echo

echo "=== Disk Usage ==="
docker system df
