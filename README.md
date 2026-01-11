# Multi-Compose Lab (Windows Docker Smoke Test) + Cleanup

ชุดตัวอย่างนี้ออกแบบให้ "เพิ่มโปรเจคได้เรื่อย ๆ" (หลายภาษา/หลายสแตก) และรันแยกกันได้โดยไม่ชนกัน
พร้อมสคริปต์ **ล้างพื้นที่ (cleanup)** สำหรับเครื่องที่ HDD จำกัด

---

## 🔄 Repository Setup (สำหรับการนำไปใช้งาน)

**ถ้าคุณต้องการนำโปรเจคนี้ไปใช้กับ repository ของตัวเอง:**

```powershell
# 1. Clone โปรเจคนี้
git clone https://github.com/geekp2p/multi-compose-labV2.git my-project
cd my-project

# 2. สร้าง repository ใหม่บน GitHub
# https://github.com/new

# 3. เปลี่ยน remote ไปยัง repository ของคุณ
.\setup-repo.ps1 -NewRepoUrl "https://github.com/your-username/your-repo-name"

# 4. Push ไปยัง repository ใหม่
git push -u origin main
```

**หรือถ้าต้องการเปลี่ยน repository ปลายทาง:**

```powershell
# เช่น เปลี่ยนจาก multi-compose-labV2 ไปเป็น compose-workbench-core
.\setup-repo.ps1 -NewRepoUrl "https://github.com/geekp2p/compose-workbench-core"
```

> 📖 **ดูคู่มือฉบับสมบูรณ์ที่:** [REPO-SETUP.md](REPO-SETUP.md)
> - การตั้งค่า authentication (HTTPS/SSH)
> - การจัดการ Git credentials
> - Workflows และ best practices

---

## ⚡ Quick Start (เริ่มต้นใช้งานภายใน 5 ขั้นตอน)

```powershell
# 1. Clone repository
git clone <repo-url>
cd multi-compose-labV2

# 2. เลือก project template ที่ต้องการรัน
.\help.ps1  # ดูรายการ projects และ templates ทั้งหมด

# 3. Start โปรเจคพร้อม build image
.\up.ps1 go-hello -Build

# 4. ทดสอบ API
curl http://localhost:8002

# 5. Stop และ cleanup เมื่อเสร็จ
.\down.ps1 go-hello
.\clean.ps1 -Project go-hello
```

**หมายเหตุ:** คำสั่งทั้งหมดรองรับ `.cmd` wrapper สำหรับ Windows เช่น `up.cmd go-hello -Build`

---

## 🎨 Available Templates

ระบบมี **5 templates** พร้อมใช้งาน เหมาะกับ use cases ต่างๆ:

| Template | Services | ภาษา | Port(s) | Use Case |
|----------|----------|------|---------|----------|
| **go-template** | 1 | Go | 8002 | Simple REST API, microservice |
| **node-template** | 1 | Node.js | 8003 | Express.js API, web backend |
| **python-template** | 1 | Python | 8001 | Flask API, ML service |
| **web-stack** | 3 | Node.js + Python + PostgreSQL | 8004-8006 | Full-stack web application |
| **microservice** | 2 | Go + Redis | 8007-8008 | Distributed system, caching layer |

**ตัวอย่างโปรเจคที่รันอยู่:**
- `go-hello` - ใช้ go-template
- `node-hello` - ใช้ node-template
- `py-hello` - ใช้ python-template
- `solo-node` - Custom stack (Bitcoin mining)

> 📖 ดูรายละเอียด templates เพิ่มเติมที่ [TEMPLATES.md](TEMPLATES.md)

---

## 📁 โครงสร้างโปรเจค

```
multi-compose-labV2/
├── up.ps1              # สคริปต์สำหรับ start โปรเจค
├── down.ps1            # สคริปต์สำหรับ stop โปรเจค
├── clean.ps1           # สคริปต์สำหรับ cleanup (3 levels)
├── service.ps1         # จัดการ services แบบละเอียด (start/stop/restart)
├── help.ps1            # คู่มือแบบ interactive
├── up.cmd / down.cmd / clean.cmd / service.cmd  # Windows batch wrappers
│
└── projects/           # โฟลเดอร์เก็บทุกโปรเจค
    ├── go-hello/       # โปรเจค Go (port 8002)
    ├── node-hello/     # โปรเจค Node.js (port 8003)
    ├── py-hello/       # โปรเจค Python (port 8001)
    └── solo-node/      # โปรเจค Custom multi-service
```

**แต่ละโปรเจค** มี Docker Compose ของตัวเองแยกกัน ทำให้:
- รันพร้อมกันได้หลายโปรเจค โดยไม่ชนกัน
- ใช้ port ต่างกัน (8001, 8002, 8003...)
- ล้างได้แยกทีละโปรเจค หรือทั้งหมดพร้อมกัน

---

## 🚀 การรันโปรเจค

### รันทีละโปรเจค (Single-Service Projects)
```powershell
# รัน Go project บน port 8002
.\up.ps1 go-hello -Build

# รัน Python project บน port 8001
.\up.ps1 py-hello -Build

# รัน Node.js project บน port 8003
.\up.ps1 node-hello -Build
```

หรือใช้ `.cmd` wrapper:
```cmd
up.cmd go-hello -Build
```

### รัน Multi-Service Projects (โปรเจคที่มีหลาย containers)

#### รัน Services ทั้งหมดพร้อมกัน
```powershell
# ตัวอย่าง: solo-node มี Bitcoin + CKPool + BFGMiner (6 services)
.\up.ps1 solo-node -Build

# Docker Compose จะรัน services ทั้งหมดใน compose.yml:
#   - bitcoin-main (Bitcoin Core mainnet)
#   - bitcoin-testnet (Bitcoin Core testnet)
#   - ckpool-main (CKPool mainnet)
#   - ckpool-test (CKPool testnet)
#   - bfgproxy-main (BFGMiner proxy mainnet)
#   - bfgproxy-test (BFGMiner proxy testnet)
```

#### รันเฉพาะบาง Services (Selective Start)
```powershell
# รันเฉพาะ testnet services
.\service.ps1 solo-node -Service bitcoin-testnet,ckpool-test -Start

# รันเฉพาะ mainnet
.\service.ps1 solo-node -Service bitcoin-main,ckpool-main,bfgproxy-main -Start

# รันเฉพาะ 1 service
.\service.ps1 solo-node -Service bitcoin-main -Start
```

#### จัดการ Services แบบละเอียด
```powershell
# List services ทั้งหมดในโปรเจค
.\service.ps1 solo-node -List

# Stop เฉพาะบาง services
.\service.ps1 solo-node -Service ckpool-main -Stop

# Restart service
.\service.ps1 solo-node -Service bitcoin-testnet -Restart

# ดู logs ของ service
.\service.ps1 solo-node -Service ckpool-main -Logs
```

**หมายเหตุ:** Services ทั้งหมดใน compose.yml เดียวกัน จะอยู่ใน network เดียวกัน สื่อสารกันได้ทันที

### รันหลายโปรเจคพร้อมกัน 🔥
เนื่องจากแต่ละโปรเจคใช้ **port แยกกัน** คุณสามารถรันหลายโปรเจคพร้อมกันได้:

```powershell
# เปิด 3 terminals แล้วรัน
.\up.ps1 go-hello -Build       # Terminal 1 → http://localhost:8002
.\up.ps1 node-hello -Build     # Terminal 2 → http://localhost:8003
.\up.ps1 py-hello -Build       # Terminal 3 → http://localhost:8001
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

### เช็คสถานะ containers ที่รันอยู่
```powershell
docker ps                        # ดูทั้งหมด
docker ps --filter "name=go-"    # ดูเฉพาะ Go project
docker compose -f projects/go-hello/compose.yml ps  # ดูเฉพาะโปรเจค

# ใช้ help.ps1 ดูสถานะ
.\help.ps1 status
```

---

## 🛑 ปิดโปรเจค (Stop + Remove containers/networks)

```powershell
# ปิดทีละโปรเจค
.\down.ps1 go-hello
.\down.ps1 node-hello

# หรือใช้ .cmd
down.cmd py-hello

# ปิดเฉพาะบาง services
.\service.ps1 solo-node -Service bitcoin-testnet -Stop
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

## 📚 สรุปคำสั่งทั้งหมด

### Repository Management
| คำสั่ง | คำอธิบาย |
|--------|----------|
| `.\setup-repo.ps1 -ShowCurrent` | ดูการตั้งค่า repository ปัจจุบัน |
| `.\setup-repo.ps1 -NewRepoUrl <url>` | เปลี่ยน repository ปลายทาง |
| `.\setup-repo.ps1 -TestConnection` | ทดสอบการเชื่อมต่อ repository |
| `.\git-helper.ps1 -Status` | ดูสถานะ Git |
| `.\git-helper.ps1 -Sync -Message "msg"` | Pull + Commit + Push |
| `.\git-helper.ps1 -Pull` | Pull จาก remote |
| `.\git-helper.ps1 -Push` | Push ไปยัง remote |

### Project Management
| คำสั่ง | คำอธิบาย |
|--------|----------|
| `.\help.ps1` | ดูคู่มือแบบ interactive |
| `.\help.ps1 status` | ดูสถานะ containers ทั้งหมด |
| `.\help.ps1 templates` | ดู templates ที่มี |

### Start/Stop Projects
| คำสั่ง | คำอธิบาย |
|--------|----------|
| `.\up.ps1 <project> -Build` | Start โปรเจค (build ใหม่) |
| `.\up.ps1 <project>` | Start โปรเจค (ใช้ image เดิม) |
| `.\down.ps1 <project>` | Stop โปรเจค (ลบ containers/networks) |

### Service Management (Multi-Service Projects)
| คำสั่ง | คำอธิบาย |
|--------|----------|
| `.\service.ps1 <project> -List` | List services ทั้งหมด |
| `.\service.ps1 <project> -Service <name> -Start` | Start service เฉพาะ |
| `.\service.ps1 <project> -Service <name> -Stop` | Stop service เฉพาะ |
| `.\service.ps1 <project> -Service <name> -Restart` | Restart service |
| `.\service.ps1 <project> -Service <name> -Logs` | ดู logs ของ service |
| `.\service.ps1 <project> -Service svc1,svc2 -Start` | Start หลาย services |

### Cleanup
| คำสั่ง | คำอธิบาย |
|--------|----------|
| `.\clean.ps1 -Project <project>` | ล้าง containers/networks ของโปรเจค |
| `.\clean.ps1 -Project <project> -Deep` | ล้างทั้ง images + volumes ของโปรเจค |
| `.\clean.ps1 -All` | ล้างทั้งระบบ (ไม่รวม volumes) |
| `.\clean.ps1 -All -Deep` | ล้างทั้งระบบ + volumes |
| `.\clean.ps1 -All -Force` | ล้างโดยไม่ถามยืนยัน |

### Docker Commands
| คำสั่ง | คำอธิบาย |
|--------|----------|
| `docker ps` | ดู containers ที่รันอยู่ |
| `docker system df` | เช็คพื้นที่ Docker |
| `docker compose -f projects/<project>/compose.yml logs -f` | ดู logs |

---

## 🎯 ตัวอย่างการใช้งานจริง (5 Scenarios)

### Scenario 1: Simple API Development
```powershell
# เริ่มพัฒนา Go API
.\up.ps1 go-hello -Build

# ทดสอบ API
curl http://localhost:8002
# Response: {"message": "Hello from Go!"}

# แก้โค้ด แล้ว rebuild
# แก้ไฟล์ projects/go-hello/main.go
.\down.ps1 go-hello
.\up.ps1 go-hello -Build

# เสร็จแล้ว ล้างพื้นที่
.\down.ps1 go-hello
.\clean.ps1 -Project go-hello
```

### Scenario 2: Full-Stack Web Development
```powershell
# รัน web stack (Node.js frontend + Python API + PostgreSQL)
.\up.ps1 web-stack -Build

# ตรวจสอบ services ทั้งหมด
.\service.ps1 web-stack -List
# Output:
#   - web-frontend (Node.js) → http://localhost:8004
#   - api-backend (Python) → http://localhost:8005
#   - postgres (Database) → localhost:5432

# ทดสอบแต่ละ service
curl http://localhost:8004  # Frontend
curl http://localhost:8005/api/health  # Backend API

# Restart เฉพาะ API (หลังแก้โค้ด)
.\service.ps1 web-stack -Service api-backend -Restart

# ดู logs ของ database
.\service.ps1 web-stack -Service postgres -Logs

# เสร็จแล้ว
.\down.ps1 web-stack
```

### Scenario 3: รันหลาย Projects พร้อมกัน (Development Environment)
```powershell
# รัน 3 APIs พร้อมกัน (แต่ละ terminal)
# Terminal 1
.\up.ps1 go-hello -Build       # Go API on :8002

# Terminal 2
.\up.ps1 node-hello -Build     # Node API on :8003

# Terminal 3
.\up.ps1 py-hello -Build       # Python API on :8001

# ทดสอบทั้ง 3 APIs
curl http://localhost:8001  # Python
curl http://localhost:8002  # Go
curl http://localhost:8003  # Node.js

# เช็คสถานะทั้งหมด
docker ps
# Output: 3 containers รันอยู่

# หยุดทีละโปรเจค
.\down.ps1 go-hello
.\down.ps1 node-hello
.\down.ps1 py-hello
```

### Scenario 4: Multi-Service Project (Bitcoin Mining Stack)
```powershell
# รัน Bitcoin mining stack ทั้งหมด (6 services)
.\up.ps1 solo-node -Build

# ตรวจสอบ services
.\service.ps1 solo-node -List
# Output:
#   - bitcoin-main, bitcoin-testnet
#   - ckpool-main, ckpool-test
#   - bfgproxy-main, bfgproxy-test

# รันเฉพาะ testnet (ประหยัดทรัพยากร)
.\down.ps1 solo-node
.\service.ps1 solo-node -Service bitcoin-testnet,ckpool-test,bfgproxy-test -Start

# ดู logs ของ ckpool
.\service.ps1 solo-node -Service ckpool-test -Logs

# Restart เฉพาะ Bitcoin node
.\service.ps1 solo-node -Service bitcoin-testnet -Restart

# เสร็จแล้ว หยุดทั้งหมด
.\down.ps1 solo-node
```

### Scenario 5: Cleanup Workflow (HDD เต็ม!)
```powershell
# สถานการณ์: HDD เหลือน้อย ต้องล้างพื้นที่

# 1. เช็คพื้นที่ที่ Docker ใช้
docker system df
# TYPE            TOTAL     ACTIVE    SIZE
# Images          15        5         4.2GB
# Containers      8         3         150MB
# Local Volumes   5         2         800MB
# Build Cache     25        0         1.5GB

# 2. ล้างโปรเจคที่ไม่ใช้แล้ว (ปกติ)
.\clean.ps1 -Project old-project

# 3. ล้างโปรเจคแบบลึก (ลบ volumes ด้วย)
.\clean.ps1 -Project py-hello -Deep

# 4. ยังไม่พอ? ล้างทั้งระบบ!
.\clean.ps1 -All -Deep -Force

# 5. บังคับคืนพื้นที่ให้ Windows (WSL2)
wsl --shutdown

# 6. เช็คอีกครั้ง
docker system df
# Images          2         2         350MB
# Containers      0         0         0B
# Volumes         0         0         0B
# Build Cache     0         0         0B
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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: secret
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
# กำหนด port ที่ไม่ซ้ำ เช่น 8010

# รันแยก
.\up.ps1 rust-api -Build  # port 8010
.\up.ps1 go-hello -Build  # port 8002
```

### 3. ดู logs ของโปรเจค
```powershell
# ใช้ service.ps1 (แนะนำ)
.\service.ps1 go-hello -Service web -Logs

# หรือใช้ Docker Compose โดยตรง
docker compose -f projects/go-hello/compose.yml logs -f

# หรือใช้ Docker
docker logs -f <container-name>
```

### 4. เข้า shell ใน container
```powershell
docker compose -f projects/go-hello/compose.yml exec web sh
docker exec -it <container-name> sh
```

### 5. ใช้ Environment Variables
```powershell
# กำหนด port แบบ dynamic
$env:HOST_PORT=9000
.\up.ps1 go-hello -Build  # จะใช้ port 9000 แทน 8002

# หรือสร้างไฟล์ .env ในโปรเจค
# projects/go-hello/.env
# HOST_PORT=9000
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

## 📖 ดูเพิ่มเติม
- **[REPO-SETUP.md](REPO-SETUP.md)** - คู่มือการตั้งค่า Git repository และ authentication
- **[TEMPLATES.md](TEMPLATES.md)** - รายละเอียด 5 templates พร้อมวิธีสร้าง custom template
- **[RECOMMENDATIONS.md](RECOMMENDATIONS.md)** - คำแนะนำ best practices
- **[CLAUDE.md](CLAUDE.md)** - กฎการ refactor และ development guidelines
- **[help.ps1](help.ps1)** - คู่มือแบบ interactive (รัน `.\help.ps1`)

### สคริปต์เสริม
- **[setup-repo.ps1](setup-repo.ps1)** - ตั้งค่าและเปลี่ยน Git repository
- **[git-helper.ps1](git-helper.ps1)** - Git operations แบบง่ายๆ

---

## 🚨 Troubleshooting

### Port ชนกัน
```powershell
# เช็คว่า port ถูกใช้งานหรือไม่
netstat -ano | findstr :8002

# แก้ไข: ใช้ environment variable
$env:HOST_PORT=9000
.\up.ps1 go-hello -Build
```

### Container ไม่ healthy
```powershell
# ดู logs เพื่อหาสาเหตุ
.\service.ps1 <project> -Service <service-name> -Logs

# Restart service
.\service.ps1 <project> -Service <service-name> -Restart
```

### Build ล้มเหลว
```powershell
# ล้าง build cache แล้ว build ใหม่
.\clean.ps1 -Project <project> -Deep
.\up.ps1 <project> -Build
```

---

## 🤝 Contributing

ต้องการเพิ่ม template ใหม่? ดูวิธีการที่ [TEMPLATES.md](TEMPLATES.md) หัวข้อ "Creating Custom Templates"

---

## 📜 License

[ดูไฟล์ LICENSE](LICENSE)
