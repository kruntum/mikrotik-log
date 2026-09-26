# MikroTik Syslog Stack (Grafana Alloy + Loki + PostgreSQL + Grafana)

ระบบจัดเก็บและค้นหา Syslog จาก MikroTik RouterOS โดยอัตโนมัติแบบครบวงจร

---

## 🏗️ สถาปัตยกรรมระบบ
- **MikroTik RouterOS**: ส่ง Syslog ออกมาผ่าน UDP พอร์ต `514`
- **Grafana Alloy**: ตัวรับ Syslog (Syslog Receiver) แปลงรูปแบบ RFC3164 และส่งต่อให้ Loki
- **Grafana Loki**: ตัวจัดเก็บ Log ประสิทธิภาพสูง บีบอัดข้อมูล ค้นหาเร็ว กำหนด Retention ไว้ 90 วัน
- **PostgreSQL**: ฐานข้อมูลหลักสำหรับ Grafana (แทนที่ SQLite) เพื่อความเสถียรและรองรับการขยายตัว
- **Grafana**: Web UI Dashboard และค้นหา Logs (พอร์ต `3301`)

---

## ⚙️ ข้อกำหนดก่อนเริ่มติดตั้ง (Linux Server Prerequisites)

### การเตรียมสิทธิ์ผู้ใช้ (Permission Setup)
หากใช้ User ทั่วไป (เช่น `tummy` บน Debian / Ubuntu) แล้วพบข้อผิดพลาด:
- `permission denied while trying to connect to the docker API`
- `user is not in the sudoers file`

ให้ทำการตั้งค่าสิทธิ์ผ่าน user `root` ดังนี้:

1. **สลับไปเป็น root:**
   ```bash
   su -
   ```
2. **เพิ่ม User เข้ากลุ่ม `sudo` และ `docker`:**
   ```bash
   usermod -aG sudo,docker <username>
   ```
   *(ตัวอย่าง: `usermod -aG sudo,docker tummy`)*

3. **สลับกลับมาใช้งาน user เดิม หรือโหลดสิทธิ์ใหม่:**
   ```bash
   newgrp docker
   ```
   *หรือออกจากระบบแล้ว SSH เข้ามาใหม่ เพื่อให้สิทธิ์มีผลสมบูรณ์*

---

## 🚀 ขั้นตอนการติดตั้งและเริ่มใช้งาน

1. **Clone โปรเจกต์ลงมาที่เครื่องเซิร์ฟเวอร์:**
   ```bash
   git clone https://github.com/kruntum/mikrotik-log.git
   cd mikrotik-log
   ```

2. **(แนะนำ) แก้ไขรหัสผ่านก่อนใช้งานจริง:**
   แก้ไขรหัสผ่านในไฟล์ `docker-compose.yml`:
   - `GF_SECURITY_ADMIN_PASSWORD`: รหัสผ่านเข้า Grafana
   - `POSTGRES_PASSWORD`: รหัสผ่านฐานข้อมูล PostgreSQL

3. **สั่งรันคอนเทนเนอร์:**
   ```bash
   docker compose up -d
   ```
   *(หากยังไม่ได้เพิ่มสิทธิ์ docker ให้ใช้ `sudo docker compose up -d`)*

4. **ตรวจสอบสถานะคอนเทนเนอร์:**
   ```bash
   docker compose ps
   ```

---

## 🌐 การเข้าใช้งาน Web UI

- **URL:** `http://<SERVER_IP>:3301`
- **Username:** `admin`
- **Password:** ตามที่กำหนดไว้ใน `docker-compose.yml`
- **Datasource:** เชื่อมต่อ Loki ให้อัตโนมัติ สามารถเข้าเมนู **Explore** เพื่อค้นหา Log ได้ทันที

---

## 🛡️ การเปิด Firewall บนเครื่อง Linux Server

ตรวจสอบว่าเครื่องเซิร์ฟเวอร์เปิดรับพอร์ตที่จำเป็น:
```bash
# พอร์ตรับ Syslog จาก MikroTik (UDP)
sudo ufw allow 514/udp

# พอร์ตเข้าใช้งานหน้าเว็บ Grafana (TCP)
sudo ufw allow 3301/tcp
```

---

## 📡 การตั้งค่าบน MikroTik RouterOS

เชื่อมต่อ Winbox หรือ Terminal ของ MikroTik แล้วรันคำสั่ง:

```routeros
# 1. เพิ่ม Remote Action ชี้ไปยัง Docker Server
/system logging action
add name=alloy-syslog remote=<SERVER_IP> remote-port=514 src-address=0.0.0.0 target=remote bsd-syslog=yes syslog-facility=daemon

# 2. เลือกหัวข้อ Log ที่ต้องการส่งเข้า Alloy / Loki
/system logging
add action=alloy-syslog topics=info
add action=alloy-syslog topics=warning
add action=alloy-syslog topics=error
add action=alloy-syslog topics=critical
add action=alloy-syslog topics=firewall
add action=alloy-syslog topics=dhcp
add action=alloy-syslog topics=account
```
*(แทนค่า `<SERVER_IP>` ด้วย IP เครื่อง Docker เช่น `10.10.10.254`)*

---

## 🔍 การตรวจสอบ Logs เมื่อพบปัญหา (Troubleshooting)

```bash
# ดู log ของ Grafana Alloy (ตัวรับ Syslog)
docker compose logs -f alloy

# ดู log ของ Loki (ฐานข้อมูล Log)
docker compose logs -f loki

# ดู log ของ Grafana
docker compose logs -f grafana

# ดู log ของ PostgreSQL
docker compose logs -f postgres
```
