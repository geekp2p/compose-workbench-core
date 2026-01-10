# Multi-Compose Lab (Windows Docker Smoke Test) + Cleanup

ชุดตัวอย่างนี้ออกแบบให้ "เพิ่มโปรเจคได้เรื่อย ๆ" (หลายภาษา/หลายสแตก) และรันแยกกันได้โดยไม่ชนกัน
พร้อมสคริปต์ **ล้างพื้นที่ (cleanup)** สำหรับเครื่องที่ HDD จำกัด

---

## 📁 โครงสร้างโปรเจค

```
multi-compose-labV2/
├── up.ps1              # สคริปต์สำหรับ start โปรเจค
├── down.ps1            # สคริปต์สำหรับ stop โปรเจค
├── clean.ps1           # สคริปต์สำหรับ cleanup (3 levels)
├── up.cmd / down.cmd / clean.cmd  # Windows batch wrappers
│
└── projects/           # โฟลเดอร์เก็บทุกโปรเจค
    ├── go-hello/       # โปรเจค Go (port 8001)
    ├── node-hello/     # โปรเจค Node.js (port 8002)
    ├── py-hello/       # โปรเจค Python (port 8003)
    └── solo-node/      # โปรเจคอื่นๆ
```

**แต่ละโปรเจค** มี Docker Compose ของตัวเองแยกกัน ทำให้:
- รันพร้อมกันได้หลายโปรเจค โดยไม่ชนกัน
- ใช้ port ต่างกัน (8001, 8002, 8003...)
- ล้างได้แยกทีละโปรเจค หรือทั้งหมดพร้อมกัน

---

## 🚀 การรันโปรเจค

### รันทีละโปรเจค
```powershell
# รัน Go project บน port 8001
.\up.ps1 go-hello -Build

# รัน Python project บน port 8003
.\up.ps1 py-hello -Build

# รัน Node.js project บน port 8002
.\up.ps1 node-hello -Build
```

หรือใช้ `.cmd` wrapper:
```cmd
up.cmd go-hello -Build
```

### รันหลายโปรเจคพร้อมกัน 🔥
เนื่องจากแต่ละโปรเจคใช้ **port แยกกัน** คุณสามารถรันหลายโปรเจคพร้อมกันได้:

```powershell
# เปิด 3 terminals แล้วรัน
.\up.ps1 go-hello -Build       # Terminal 1 → http://localhost:8001
.\up.ps1 node-hello -Build     # Terminal 2 → http://localhost:8002
.\up.ps1 py-hello -Build       # Terminal 3 → http://localhost:8003
```

หรือรันแบบ background (detached mode):
```powershell
# รันทั้งหมดใน background
docker compose -f projects/go-hello/compose.yml up -d --build
docker compose -f projects/node-hello/compose.yml up -d --build
docker compose -f projects/py-hello/compose.yml up -d --build

# เช็คสถานะทั้งหมด
docker ps
```

### ตัวอย่างการรัน Sub-Projects ในโปรเจคเดียวกัน
ถ้าคุณมีโปรเจคที่มี **หลาย containers** (เช่น API + Database):

```powershell
# ตัวอย่าง: solo-node มี Node.js + PostgreSQL + Redis
.\up.ps1 solo-node -Build

# Docker Compose จะรัน services ทั้งหมดใน compose.yml:
#   - solo-node-web (Node.js API)
#   - solo-node-db (PostgreSQL)
#   - solo-node-cache (Redis)
```

**หมายเหตุ:** Services ทั้งหมดใน compose.yml เดียวกัน จะอยู่ใน network เดียวกัน สื่อสารกันได้ทันที

### เช็คสถานะ containers ที่รันอยู่
```powershell
docker ps                        # ดูทั้งหมด
docker ps --filter "name=go-"    # ดูเฉพาะ Go project
docker compose -f projects/go-hello/compose.yml ps  # ดูเฉพาะโปรเจค
```

---

## 🛑 ปิดโปรเจค (Stop + Remove containers/networks)

```powershell
# ปิดทีละโปรเจค
.\down.ps1 go-hello
.\down.ps1 node-hello

# หรือใช้ .cmd
down.cmd py-hello
```

**สิ่งที่เกิดขึ้น:**
- หยุด containers ทั้งหมดของโปรเจค
- ลบ containers
- ลบ networks
- **ไม่** ลบ images และ volumes (ข้อมูลยังอยู่)

---

## 🧹 ล้างพื้นที่ (Cleanup)

### 1️⃣ ล้างแบบ "เฉพาะโปรเจค" (Normal)
หยุด + ลบ containers/networks เท่านั้น
```powershell
.\clean.ps1 -Project go-hello
```

### 2️⃣ ล้างแบบ "ลึก" (Deep) - ลบทั้ง Images + Volumes
⚠️ **ระวัง:** จะลบ volumes (ข้อมูล DB หาย!)
```powershell
.\clean.ps1 -Project go-hello -Deep
```

**สิ่งที่เกิดขึ้น:**
- ลบ containers/networks
- ลบ **local images** ที่ build จากโปรเจค
- ลบ **volumes** ของโปรเจค (ข้อมูลถาวรหาย)

### 3️⃣ ล้างแบบ "ทั้งเครื่อง" (System-wide)
⚠️ **ระวัง:** จะลบทุกอย่างใน Docker!
```powershell
# ล้าง build cache + dangling images + stopped containers
.\clean.ps1 -All

# ล้างทั้งหมด + volumes ของทุกโปรเจค
.\clean.ps1 -All -Deep
```

**สิ่งที่เกิดขึ้น:**
- `docker system prune -af` (ลบ containers, networks, images ที่ไม่ใช้งาน)
- ลบ build cache
- ถ้าใช้ `-Deep` จะลบ volumes ทั้งหมดด้วย

### 4️⃣ ล้างแบบ "บังคับ" (Force) - ไม่ถามยืนยัน
```powershell
.\clean.ps1 -Project go-hello -Deep -Force
.\clean.ps1 -All -Deep -Force
```

---

## 📊 เช็คพื้นที่ Docker ใช้ไปเท่าไหร่

```powershell
# ดูสรุป
docker system df

# ดูแบบละเอียด
docker system df -v

# ดูขนาด images
docker images

# ดูขนาด volumes
docker volume ls
```

---

## 💡 Tips & Best Practices

### 1. รันหลาย Docker ใน sub ของโปรเจคเดียวกัน
ตัวอย่าง `compose.yml` ที่มีหลาย services:

```yaml
# projects/my-app/compose.yml
services:
  web:
    build: .
    ports:
      - "8080:3000"
    depends_on:
      - db
      - cache

  db:
    image: postgres:15-alpine
    volumes:
      - db-data:/var/lib/postgresql/data

  cache:
    image: redis:7-alpine

volumes:
  db-data:
```

รันด้วย:
```powershell
.\up.ps1 my-app -Build
# จะรัน web + db + cache พร้อมกัน
```

### 2. แยก run แต่ละโปรเจค
เพิ่มโปรเจคใหม่ใน `projects/` และรันแยก:

```powershell
# สร้างโปรเจคใหม่
mkdir projects/rust-api
# เพิ่ม Dockerfile และ compose.yml
# กำหนด port ที่ไม่ซ้ำ เช่น 8004

# รันแยก
.\up.ps1 rust-api -Build  # port 8004
.\up.ps1 go-hello -Build  # port 8001
```

### 3. ดู logs ของโปรเจค
```powershell
docker compose -f projects/go-hello/compose.yml logs -f
docker logs -f <container-name>
```

### 4. เข้า shell ใน container
```powershell
docker compose -f projects/go-hello/compose.yml exec web sh
docker exec -it <container-name> sh
```

---

## 🔧 ถ้าใช้ Docker Desktop + WSL2 แล้วพื้นที่ยังไม่คืน

หลังจาก cleanup แล้ว พื้นที่อาจไม่คืนทันที ให้รัน:

```powershell
# Shutdown WSL
wsl --shutdown

# เปิด Docker Desktop ใหม่
# WSL จะคืนพื้นที่ให้ Windows
```

หรือ Compact WSL disk ด้วยตนเอง:
```powershell
# หา path ของ WSL disk
wsl --list -v

# Compact (ใช้เวลานาน)
wsl --shutdown
Optimize-VHD -Path "C:\Users\<User>\AppData\Local\Docker\wsl\data\ext4.vhdx" -Mode Full
```

---

## 📚 สรุปคำสั่ง

| คำสั่ง | คำอธิบาย |
|--------|----------|
| `.\up.ps1 <project> -Build` | Start โปรเจค (build ใหม่) |
| `.\down.ps1 <project>` | Stop โปรเจค (ลบ containers/networks) |
| `.\clean.ps1 -Project <project>` | ล้าง containers/networks ของโปรเจค |
| `.\clean.ps1 -Project <project> -Deep` | ล้างทั้ง images + volumes ของโปรเจค |
| `.\clean.ps1 -All` | ล้างทั้งระบบ (ไม่รวม volumes) |
| `.\clean.ps1 -All -Deep` | ล้างทั้งระบบ + volumes |
| `docker ps` | ดู containers ที่รันอยู่ |
| `docker system df` | เช็คพื้นที่ Docker |

---

## 🎯 ตัวอย่างการใช้งานจริง

```powershell
# Scenario 1: รัน Go + Python พร้อมกัน
.\up.ps1 go-hello -Build
.\up.ps1 py-hello -Build

# เช็ค
docker ps
curl http://localhost:8001  # Go
curl http://localhost:8003  # Python

# ปิดทั้งคู่
.\down.ps1 go-hello
.\down.ps1 py-hello

# ล้าง (เก็บ images)
.\clean.ps1 -Project go-hello
.\clean.ps1 -Project py-hello

# Scenario 2: ล้างพื้นที่ทั้งหมด (HDD เต็ม!)
.\clean.ps1 -All -Deep -Force
wsl --shutdown
```

---

## 📖 ดูเพิ่มเติม
- [RECOMMENDATIONS.md](RECOMMENDATIONS.md) - คำแนะนำ best practices
- [CLAUDE.md](CLAUDE.md) - กฎการ refactor
