#!/usr/bin/env bash
# ==============================================================================
# Script: restore.sh
# Purpose: กู้คืนข้อมูล (Restore) PostgreSQL และ Loki จากไฟล์สำรอง
# Usage: ./scripts/restore.sh <postgres_backup.sql.gz> <loki_backup.tar.gz>
# ==============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "${PROJECT_DIR}/.env" ]; then
    # shellcheck disable=SC1091
    export $(grep -v '^#' "${PROJECT_DIR}/.env" | xargs)
fi

DB_USER="${POSTGRES_USER:-grafana}"
DB_NAME="${POSTGRES_DB:-grafana}"

echo "========================================================"
echo " ระบบกู้คืนข้อมูล (Disaster Recovery & Restore)"
echo "========================================================"

if [ "$#" -lt 1 ]; then
    echo "วิธีใช้งาน:"
    echo "  1. กู้คืนเฉพาะ PostgreSQL (Dashboards, Users):"
    echo "     $0 <path_to_postgres_backup.sql.gz>"
    echo ""
    echo "  2. กู้คืนทั้ง PostgreSQL และ Loki Log:"
    echo "     $0 <path_to_postgres_backup.sql.gz> <path_to_loki_backup.tar.gz>"
    exit 1
fi

POSTGRES_FILE="$1"

if [ ! -f "${POSTGRES_FILE}" ]; then
    echo "Error: ไม่พบไฟล์ ${POSTGRES_FILE}" >&2
    exit 1
fi

echo "--> 1. กำลังกู้คืนฐานข้อมูล PostgreSQL จาก ${POSTGRES_FILE}..."
gunzip -c "${POSTGRES_FILE}" | docker exec -i postgres psql -U "${DB_USER}" -d "${DB_NAME}"
echo "    [SUCCESS] กู้คืน PostgreSQL สำเร็จ!"

if [ "$#" -ge 2 ]; then
    LOKI_FILE="$2"
    if [ ! -f "${LOKI_FILE}" ]; then
        echo "Error: ไม่พบไฟล์ ${LOKI_FILE}" >&2
        exit 1
    fi
    echo "--> 2. กำลังกู้คืนข้อมูล Loki Log Chunks จาก ${LOKI_FILE}..."
    docker compose stop loki
    docker run --rm \
        --volumes-from loki \
        -v "$(dirname "$(realpath "${LOKI_FILE}")"):/backup" \
        alpine sh -c "rm -rf /loki/* && tar xzf /backup/$(basename "${LOKI_FILE}") -C /loki"
    docker compose start loki
    echo "    [SUCCESS] กู้คืน Loki Log Chunks สำเร็จ!"
fi

echo "========================================================"
echo " กู้คืนข้อมูลเรียบร้อยแล้ว!"
echo "========================================================"
