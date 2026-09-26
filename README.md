# 📘 คู่มือการใช้งานระบบจัดเก็บและค้นหา MikroTik Log (ฉบับปฏิบัติการสำหรับพนักงานและผู้ดูแลระบบ)

ระบบรวมศูนย์และวิเคราะห์ข้อมูล Log จาก MikroTik RouterOS แบบอัตโนมัติ โดยใช้ **Grafana Alloy + Loki + PostgreSQL + Grafana** ออกแบบมาเพื่อให้สอดคล้องกับการเก็บรักษาข้อมูลจราจรทางคอมพิวเตอร์ (Log 90 วัน) และง่ายต่อการสืบค้นข้อมูลสำหรับฝ่าย IT

---

## 📑 สารบัญ
1. [สถาปัตยกรรมและการทำงานของระบบ](#1-สถาปัตยกรรมและการทำงานของระบบ)
2. [ข้อมูลการเชื่อมต่อและพอร์ตที่ใช้งาน](#2-ข้อมูลการเชื่อมต่อและพอร์ตที่ใช้งาน)
3. [ขั้นตอนการติดตั้งระบบ (สำหรับผู้ดูแลเซิร์ฟเวอร์)](#3-ขั้นตอนการติดตั้งระบบ-สำหรับผู้ดูแลเซิร์ฟเวอร์)
4. [การตั้งค่าบน MikroTik RouterOS](#4-การตั้งค่าบน-mikrotik-routeros)
5. [คู่มือการใช้งาน Grafana สำหรับพนักงาน (ค้นหา Log)](#5-คู่มือการใช้งาน-grafana-สำหรับพนักงาน-ค้นหา-log)
6. [สูตรการค้นหา Log ยอดนิยม (LogQL Cheat Sheet)](#6-สูตรการค้นหา-log-ยอดนิยม-logql-cheat-sheet)
7. [การดูแลรักษาและการสำรองข้อมูล (Maintenance)](#7-การดูแลรักษาและการสำรองข้อมูล-maintenance)
8. [การแก้ปัญหาที่พบบ่อย (Troubleshooting)](#8-การแก้ปัญหาที่พบบ่อย-troubleshooting)

---

## 1. สถาปัตยกรรมและการทำงานของระบบ

```
[ MikroTik RouterOS ] 
        │ (UDP 514 / RFC 3164 Syslog)
        ▼
[ Grafana Alloy ] (Syslog Collector / Buffer)
        │ (HTTP Push API)
        ▼
[ Grafana Loki ] ── (เก็บบน Disk บีบอัดสูง / TSDB Index / Retention 90 วัน)
        ▲
        │
[ Grafana Web UI ] ◄───► [ PostgreSQL 16 ] (เก็บ User, Dashboards, Alerts)
        ▲
        │
[ พนักงาน / ผู้ดูแลระบบ ] (เปิดผ่าน Browser พอร์ต 3301)
```

---

## 2. ข้อมูลการเชื่อมต่อและพอร์ตที่ใช้งาน

| บริการ | โปรโตคอล / พอร์ต | ปลายทาง / วัตถุประสงค์ |
|---|---|---|
| **Grafana Web UI** | TCP `3301` | หน้า Dashboard ค้นหา Log สำหรับพนักงาน |
| **Syslog Receiver (Alloy)** | UDP `514` | รับข้อมูล Log จากเราเตอร์ MikroTik |
| **Grafana Loki** | TCP `3100` | ฐานข้อมูล Log ภายใน (เข้าถึงเฉพาะ localhost) |
| **PostgreSQL** | TCP `5432` | ฐานข้อมูลการตั้งค่า Grafana ภายใน Docker Network |

* **URL เข้าใช้งาน:** `http://<SERVER_IP>:3301`
* **Username เริ่มต้น:** `admin`
* **Password:** กำหนดไว้ในไฟล์ `.env` ของเซิร์ฟเวอร์

---

## 3. ขั้นตอนการติดตั้งระบบ (สำหรับผู้ดูแลเซิร์ฟเวอร์)

### 3.1 ข้อกำหนดและการเตรียมสิทธิ์ผู้ใช้ Linux (Debian / Ubuntu)
หากใช้ User ทั่วไป (เช่น `tummy`) แล้วติดปัญหาเรื่องสิทธิ์:
```bash
# 1. สลับไปเป็น root
su -

# 2. เพิ่มสิทธิ์ให้ user เข้ากลุ่ม sudo และ docker
usermod -aG sudo,docker <username>

# 3. โหลดสิทธิ์ใหม่
newgrp docker
```

### 3.2 การติดตั้งและเปิดใช้งานคอนเทนเนอร์
```bash
# 1. Clone โปรเจกต์ลงมา
git clone https://github.com/kruntum/mikrotik-log.git
cd mikrotik-log

# 2. กรณีสลับ user แล้วติดเรื่องสิทธิ์ Git
git config --global --add safe.directory $(pwd)

# 3. สร้างไฟล์รหัสผ่านความปลอดภัย (.env)
cp .env.example .env
nano .env   # แก้ไขรหัสผ่าน GF_SECURITY_ADMIN_PASSWORD และ POSTGRES_PASSWORD

# 4. สั่งรันระบบทั้งหมด
docker compose up -d

# 5. ตรวจสอบสถานะการทำงาน (ต้องขึ้น running ครบทั้ง 4 ตัว)
docker compose ps
```

### 3.3 การเปิด Firewall บนเซิร์ฟเวอร์
```bash
sudo ufw allow 514/udp    # พอร์ตรับ Syslog จาก MikroTik
sudo ufw allow 3301/tcp   # พอร์ตเข้าหน้าเว็บ Grafana
```

---

## 4. การตั้งค่าบน MikroTik RouterOS

ล็อกอินเข้า Winbox หรือ SSH ของเราเตอร์ MikroTik แล้วเปิด **Terminal** รันคำสั่งด้านล่างนี้ (แทน `<SERVER_IP>` ด้วย IP เครื่องเซิร์ฟเวอร์ เช่น `10.10.10.254`):

```routeros
# 1. สร้าง Action ส่ง Syslog ไปยังเซิร์ฟเวอร์ (สำคัญ: ต้องใช้ remote-log-format=syslog สำหรับ RouterOS v7)
/system logging action
add name=alloy target=remote remote=<SERVER_IP> remote-port=514 remote-log-format=syslog syslog-time-format=bsd-syslog

# 2. กำหนดประเภท Logs สำคัญที่ต้องการส่งเข้าศูนย์เก็บ
/system logging
add action=alloy topics=info
add action=alloy topics=warning
add action=alloy topics=error
add action=alloy topics=critical
add action=alloy topics=firewall
add action=alloy topics=dhcp
add action=alloy topics=account
```

### คำสั่งทดสอบการส่ง Log จาก MikroTik:
```routeros
/log info "=== TEST SYSLOG CONNECTION TO ALLOY ==="
```

---

## 5. คู่มือการใช้งาน Grafana สำหรับพนักงาน (ค้นหา Log)

### 5.1 การเข้าสู่ระบบ
1. เปิดเบราว์เซอร์ไปที่: `http://<SERVER_IP>:3301`
2. กรอก **Username** และ **Password** ที่ได้รับมอบหมาย
3. เมนูด้านซ้ายคลิกที่ไอคอน **Explore** (รูปเข็มทิศ 🧭) หรือไปที่ `http://<SERVER_IP>:3301/explore`

### 5.2 วิธีการค้นหา
1. ที่มุมซ้ายบน ตรวจสอบว่า Data source เลือกเป็น **`Loki`**
2. ที่มุมขวาบนของช่องค้นหา ให้คลิกสลับปุ่มไปที่โหมด **`Code`**
3. พิมพ์คำสั่งสืบค้น (LogQL) เช่น `{job="mikrotik"}`
4. กำหนดช่วงเวลาที่ต้องการค้นหาที่มุมบนขวา (เช่น `Last 1 hour`, `Today`, หรือระบุวันเวลาเจาะจง)
5. กดปุ่มสีน้ำเงิน **Run query** (หรือกด `Shift + Enter`)

### 5.3 การเปิดดู Log สดแบบเรียลไทม์ (Live Streaming)
* คลิกที่ปุ่ม **"Live"** (มุมขวาบน) หน้าจอจะแสดง Log ล่าสุดที่อุปกรณ์กำลังส่งเข้ามาอย่างต่อเนื่องโดยไม่ต้องกดรีเฟรช

---

## 6. สูตรการค้นหา Log ยอดนิยม (LogQL Cheat Sheet)

พนักงานสามารถคัดลอกคำสั่งด้านล่างนี้ไปปรับใช้ในช่อง Query ได้ทันที:

| วัตถุประสงค์ในการค้นหา | คำสั่ง LogQL ที่ใช้งาน |
|---|---|
| **ดู Log ทั้งหมดของ MikroTik** | `{job="mikrotik"}` |
| **ค้นหาตาม IP ภายใน/ภายนอก** | `{job="mikrotik"} \|= "192.168.1.150"` |
| **ค้นหาตาม MAC Address** | `{job="mikrotik"} \|= "00:11:22:AA:BB:CC"` |
| **ตรวจสอบการแจก IP ของ DHCP** | `{job="mikrotik"} \|= "dhcp"` |
| **ดู Log ที่ถูก Firewall Drop / บล็อก** | `{job="mikrotik"} \|= "firewall" \|= "drop"` |
| **ดู Log การ Forward ข้อมูลผ่านเราเตอร์** | `{job="mikrotik"} \|= "forward:"` |
| **ตรวจจับการพยายาม Brute-Force Login ล้มเหลว** | `{job="mikrotik"} \|= "login failure"` |
| **ดูเฉพาะเหตุการณ์แจ้งเตือนระดับ Warning หรือ Error** | `{job="mikrotik"} \|~ "warning\|error\|critical"` |
| **ค้นหาแบบตัดคำที่ไม่ต้องการออก (เช่น ไม่เอา DNS)** | `{job="mikrotik"} \|= "firewall" != "dns"` |

---

## 7. การดูแลรักษาและการสำรองข้อมูล (Maintenance)

### 7.1 นโยบายการเก็บรักษาข้อมูล (Log Retention)
* ระบบตั้งค่าไว้ที่ **90 วัน (2,160 ชั่วโมง)** ตามข้อกำหนดทางกฎหมาย เมื่อพ้นระยะเวลาดังกล่าว Loki Compactor จะทำการลบข้อมูลเก่าทิ้งโดยอัตโนมัติ เพื่อประหยัดพื้นที่ดิสก์

### 7.2 คำสั่งตรวจสอบสถานะและการทำงาน
```bash
# ตรวจสอบว่าคอนเทนเนอร์ทำงานปกติทุกตัว
docker compose ps

# ดู Log รวมของทั้งระบบ
docker compose logs -f

# ดู Log แยกตามแต่ละเซอร์วิส
docker compose logs -f alloy      # ตัวรับ Syslog
docker compose logs -f loki       # ฐานข้อมูล Log
docker compose logs -f grafana    # หน้าเว็บ
docker compose logs -f postgres   # ฐานข้อมูล Grafana
```

### 7.3 ระบบสำรองข้อมูลอัตโนมัติ (Automated Backup & Restore)

ระบบมีสคริปต์สำหรับการสำรองและกู้คืนข้อมูลแบบพร้อมใช้งานทันทีอยู่ในโฟลเดอร์ `scripts/`:

#### 1) การสั่ง Backup ทันที (Manual):
```bash
# ให้สิทธิ์รันสคริปต์
chmod +x scripts/*.sh

# สั่งสำรองข้อมูลทันที
./scripts/backup.sh
```
*สคริปต์จะทำการสำรองทั้ง PostgreSQL (Users, Dashboards), Loki Log Chunks, และไฟล์การตั้งค่า ลงในโฟลเดอร์ `backups/` และจะลบไฟล์สำรองที่เก่าเกิน 30 วันให้อัตโนมัติ*

#### 2) การตั้งเวลาสำรองข้อมูลอัตโนมัติทุกวัน (Cron Job):
เปิด crontab:
```bash
crontab -e
```
เพิ่มบรรทัดนี้ลงไปด้านล่างสุด เพื่อให้สำรองข้อมูลอัตโนมัติทุกวันเวลา 02:00 น.:
```cron
0 2 * * * /home/tummy/mikrotik-log/scripts/backup.sh >> /var/log/mikrotik-backup.log 2>&1
```

#### 3) การกู้คืนข้อมูล (Disaster Recovery / Restore):
```bash
# กู้คืนเฉพาะฐานข้อมูล Grafana
./scripts/restore.sh backups/postgres_grafana_YYYYMMDD_HHMMSS.sql.gz

# หรือกู้คืนทั้ง Grafana และ Loki Logs
./scripts/restore.sh backups/postgres_grafana_YYYYMMDD_HHMMSS.sql.gz backups/loki_data_YYYYMMDD_HHMMSS.tar.gz
```

---

## 8. การแก้ปัญหาที่พบบ่อย (Troubleshooting)

| อาการที่พบ | สาเหตุ | วิธีแก้ไข |
|---|---|---|
| **Alloy แจ้ง `invalid or unsupported framing, first byte: 'f'`** | MikroTik ส่ง Log เป็น raw text ไม่ตรงมาตรฐาน RFC 3164 | รันคำสั่งบน MikroTik: `/system logging action set [find name=alloy] remote-log-format=syslog syslog-time-format=bsd-syslog` |
| **Grafana ค้างสถานะ `restarting` (pq: password authentication failed)** | PostgreSQL จำรหัสผ่านเก่าจากตอนสร้างครั้งแรก | รัน: `docker compose down` ตามด้วย `docker volume rm mikrotik-log_postgres-data` แล้วรัน `docker compose up -d` ใหม่ |
| **Loki ค้างสถานะ `restarting` (delete_request_store required)** | ไฟล์ config ขาดตัวแปร retention compactor | เพิ่ม `delete_request_store: filesystem` ใต้หัวข้อ `compactor` ใน `loki/config.yml` แล้ว restart |
| **Git ฟ้อง `detected dubious ownership`** | รัน git ด้วย user ที่ไม่ใช่เจ้าของโฟลเดอร์เดิม | รัน: `git config --global --add safe.directory $(pwd)` |
| **ไม่พบ Log ใน Grafana เลย** | Firewall บล็อกพอร์ต UDP หรือคำสั่งค้นหาผิด | 1. ตรวจสอบ firewall `sudo ufw allow 514/udp`<br>2. ในหน้า Explore ต้องใช้โหมด **Code** และใส่ `{job="mikrotik"}` |
