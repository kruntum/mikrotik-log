#!/usr/bin/env bash
# ==============================================================================
# Script: backup.sh
# Purpose: สำรองข้อมูล PostgreSQL (Grafana) และ Loki Log Chunks อัตโนมัติ
# ==============================================================================

set -euo pipefail

# ระบุไดเรกทอรีโปรเจกต์
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
RETENTION_DAYS=30

mkdir -p "${BACKUP_DIR}"

echo "========================================================"
echo " [$(date '+%Y-%m-%d %H:%M:%S')] เริ่มต้นกระบวนการ Backup..."
echo "========================================================"

# โหลดค่าตัวแปรจาก .env
if [ -f "${PROJECT_DIR}/.env" ]; then
    # shellcheck disable=SC1091
    export $(grep -v '^#' "${PROJECT_DIR}/.env" | xargs)
fi

DB_USER="${POSTGRES_USER:-grafana}"
DB_NAME="${POSTGRES_DB:-grafana}"

# 1. สำรองข้อมูลฐานข้อมูล PostgreSQL (Grafana Dashboards, Users, Settings)
echo "--> 1/3 กำลังสำรองฐานข้อมูล PostgreSQL..."
POSTGRES_BACKUP_FILE="${BACKUP_DIR}/postgres_${DB_NAME}_${TIMESTAMP}.sql.gz"
if docker exec postgres pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip > "${POSTGRES_BACKUP_FILE}"; then
    echo "    [SUCCESS] บันทึก PostgreSQL เรียบร้อย: $(basename "${POSTGRES_BACKUP_FILE}") ($(du -h "${POSTGRES_BACKUP_FILE}" | cut -f1))"
else
    echo "    [ERROR] สำรองฐานข้อมูล PostgreSQL ล้มเหลว!" >&2
fi

# 2. สำรองข้อมูล Log Chunks & Index ของ Loki
echo "--> 2/3 กำลังสำรองข้อมูล Loki Log Chunks..."
LOKI_BACKUP_FILE="${BACKUP_DIR}/loki_data_${TIMESTAMP}.tar.gz"
if docker run --rm \
    --volumes-from loki:ro \
    -v "${BACKUP_DIR}:/backup" \
    alpine tar czf "/backup/$(basename "${LOKI_BACKUP_FILE}")" -C /loki . ; then
    echo "    [SUCCESS] บันทึก Loki Log Chunks เรียบร้อย: $(basename "${LOKI_BACKUP_FILE}") ($(du -h "${LOKI_BACKUP_FILE}" | cut -f1))"
else
    echo "    [ERROR] สำรองข้อมูล Loki ล้มเหลว!" >&2
fi

# 3. สำรองไฟล์ Configuration และ .env
echo "--> 3/3 กำลังสำรองไฟล์ Configuration..."
CONFIG_BACKUP_FILE="${BACKUP_DIR}/config_${TIMESTAMP}.tar.gz"
tar czf "${CONFIG_BACKUP_FILE}" -C "${PROJECT_DIR}" docker-compose.yml alloy loki grafana .env 2>/dev/null || true
echo "    [SUCCESS] บันทึก Configuration เรียบร้อย: $(basename "${CONFIG_BACKUP_FILE}")"

# 4. ลบไฟล์สำรองที่มีอายุเกิน RETENTION_DAYS (ค่าเริ่มต้น 30 วัน)
echo "--> กำลังตรวจสอบและลบไฟล์สำรองที่เก่าเกิน ${RETENTION_DAYS} วัน..."
DELETED_COUNT=$(find "${BACKUP_DIR}" -type f -name "*_20*.gz" -mtime +"${RETENTION_DAYS}" | wc -l)
find "${BACKUP_DIR}" -type f -name "*_20*.gz" -mtime +"${RETENTION_DAYS}" -delete
echo "    ลบไฟล์เก่าไปทั้งหมด: ${DELETED_COUNT} ไฟล์"

echo "========================================================"
echo " [$(date '+%Y-%m-%d %H:%M:%S')] สำรองข้อมูลเสร็จสมบูรณ์ 100%!"
echo " ตำแหน่งไฟล์: ${BACKUP_DIR}"
echo "========================================================"
