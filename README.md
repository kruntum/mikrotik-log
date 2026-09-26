# MikroTik Syslog Stack (Grafana Alloy + Loki + PostgreSQL + Grafana)

ระบบจัดเก็บและค้นหา Syslog จาก MikroTik RouterOS โดยอัตโนมัติ

## สถาปัตยกรรมระบบ
- **MikroTik RouterOS**: ส่ง Syslog ผ่าน UDP พอร์ต 514
- **Grafana Alloy**: ตัวรับ Syslog (Syslog Receiver) แปลง format และส่งต่อให้ Loki
- **Grafana Loki**: ตัวจัดเก็บ Log แบบบีบอัดและค้นหาเร็ว (Retention 90 วัน)
- **PostgreSQL**: ฐานข้อมูลหลักของ Grafana สำหรับเก็บข้อมูล Dashboard, User และการตั้งค่า
- **Grafana**: Web UI สำหรับดู Dashboard และค้นหา Logs (พอร์ต 3301)

## การติดตั้งและเริ่มใช้งาน

```bash
git clone <YOUR_REPO_URL>
cd mikrotik-log
docker compose up -d
```

## การเข้าใช้งาน
- Web UI: `http://<SERVER_IP>:3301`
- Username: `admin`
- Password: ดูใน `docker-compose.yml`

## การตั้งค่าบน MikroTik RouterOS
```routeros
/system logging action
add name=alloy-syslog remote=<SERVER_IP> remote-port=514 src-address=0.0.0.0 target=remote bsd-syslog=yes syslog-facility=daemon

/system logging
add action=alloy-syslog topics=info
add action=alloy-syslog topics=warning
add action=alloy-syslog topics=error
add action=alloy-syslog topics=critical
add action=alloy-syslog topics=firewall
add action=alloy-syslog topics=dhcp
add action=alloy-syslog topics=account
```
