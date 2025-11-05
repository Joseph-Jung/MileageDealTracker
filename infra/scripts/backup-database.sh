#!/bin/bash
set -e

# Database Backup Script for Azure PostgreSQL
# Usage: ./backup-database.sh [environment]

ENVIRONMENT=${1:-prod}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$(dirname "$0")/../../backups"
BACKUP_FILE="$BACKUP_DIR/mileage_tracker_${ENVIRONMENT}_${TIMESTAMP}.sql"

echo "========================================="
echo "Database Backup"
echo "Environment: $ENVIRONMENT"
echo "Timestamp: $TIMESTAMP"
echo "========================================="

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Environment must be dev, staging, or prod"
    exit 1
fi

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo "Error: DATABASE_URL environment variable is not set"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Parse DATABASE_URL to extract connection details
# Format: postgresql://username:password@host:port/database?params
DB_URL=$DATABASE_URL

# Extract components using parameter expansion
# Remove protocol
DB_URL_CLEAN=${DB_URL#postgresql://}
# Extract username and password
USER_PASS=${DB_URL_CLEAN%%@*}
USERNAME=${USER_PASS%%:*}
PASSWORD=${USER_PASS#*:}
# Extract host, port, database
HOST_PORT_DB=${DB_URL_CLEAN#*@}
HOST_PORT=${HOST_PORT_DB%%/*}
HOST=${HOST_PORT%%:*}
PORT=${HOST_PORT#*:}
PORT=${PORT%%/*}
# Extract database name
DB_WITH_PARAMS=${HOST_PORT_DB#*/}
DATABASE=${DB_WITH_PARAMS%%\?*}

echo "Backing up database: $DATABASE"
echo "Host: $HOST"
echo "Port: $PORT"
echo "Backup file: $BACKUP_FILE"

# Set password for pg_dump
export PGPASSWORD=$PASSWORD

# Run pg_dump
echo "Running pg_dump..."
pg_dump -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DATABASE" \
    --no-owner --no-acl --clean --if-exists \
    -f "$BACKUP_FILE"

# Unset password
unset PGPASSWORD

# Compress backup
echo "Compressing backup..."
gzip "$BACKUP_FILE"

COMPRESSED_FILE="${BACKUP_FILE}.gz"
FILE_SIZE=$(ls -lh "$COMPRESSED_FILE" | awk '{print $5}')

echo "========================================="
echo "Backup complete!"
echo "File: $COMPRESSED_FILE"
echo "Size: $FILE_SIZE"
echo "========================================="

# Optional: Upload to Azure Storage (if Azure CLI is configured)
if command -v az &> /dev/null; then
    read -p "Upload backup to Azure Blob Storage? (yes/no): " -r
    if [[ $REPLY =~ ^yes$ ]]; then
        echo "Uploading to Azure Storage..."

        STORAGE_ACCOUNT="mileagedealtrackerstprod"
        CONTAINER_NAME="database-backups"
        BLOB_NAME="mileage_tracker_${ENVIRONMENT}_${TIMESTAMP}.sql.gz"

        az storage blob upload \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$CONTAINER_NAME" \
            --name "$BLOB_NAME" \
            --file "$COMPRESSED_FILE" \
            --auth-mode login

        echo "Backup uploaded to Azure Storage: $BLOB_NAME"
    fi
fi

echo "Done!"
