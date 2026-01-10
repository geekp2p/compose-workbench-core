# แนะนำการปรับปรุงเป็น Universal Docker Template

## 🎯 เป้าหมาย
1. รองรับทุกภาษา (Go, Node, Python, Rust, Java, PHP, .NET, etc.)
2. Run ได้ง่ายด้วยคำสั่งสั้นๆ
3. ล้างทรัพยากรได้สะอาดหมดจด
4. Template-driven สร้าง project ใหม่ได้ในไม่กี่วินาที

---

## 📁 โครงสร้างที่แนะนำ

```
multi-compose-lab/
├── templates/                    # Template สำหรับแต่ละภาษา
│   ├── languages/
│   │   ├── go/
│   │   │   ├── Dockerfile.template
│   │   │   ├── compose.yml.template
│   │   │   ├── main.go.template
│   │   │   └── go.mod.template
│   │   ├── node/
│   │   │   ├── Dockerfile.template
│   │   │   ├── compose.yml.template
│   │   │   ├── server.js.template
│   │   │   └── package.json.template
│   │   ├── python/
│   │   │   ├── Dockerfile.template
│   │   │   ├── compose.yml.template
│   │   │   ├── app.py.template
│   │   │   └── requirements.txt.template
│   │   ├── rust/
│   │   ├── java/
│   │   ├── php/
│   │   ├── dotnet/
│   │   └── ruby/
│   └── config/
│       ├── .env.template
│       ├── .gitignore.template
│       └── README.template.md
├── scripts/                      # คำสั่งต่างๆ
│   ├── run.ps1                  # Main entry point (เรียกคำสั่งอื่นๆ)
│   ├── new.ps1                  # สร้าง project ใหม่จาก template
│   ├── up.ps1                   # Start project
│   ├── down.ps1                 # Stop project
│   ├── restart.ps1              # Restart project
│   ├── clean.ps1                # Clean resources
│   ├── logs.ps1                 # View logs
│   ├── shell.ps1                # Enter container shell
│   ├── ps.ps1                   # List running containers
│   ├── health.ps1               # Check project health
│   └── common.psm1              # Shared functions
├── projects/                     # โปรเจคจริงๆ
│   ├── go-hello/
│   ├── node-hello/
│   ├── py-hello/
│   └── [your-new-projects]/
├── config/                       # Global configs
│   ├── ports.json               # Port registry
│   └── defaults.json            # Default settings
├── run.cmd                       # CMD wrapper for run.ps1
└── README.md
```

---

## 🚀 คำสั่งที่แนะนำให้มี

### Option 1: Single Entry Point (แนะนำ)
```powershell
# run.ps1 - คำสั่งหลัก
.\run.ps1 <command> <project> [options]

# ตัวอย่าง:
.\run.ps1 new my-api -Lang go          # สร้าง project ใหม่
.\run.ps1 up my-api -Build             # Start + build
.\run.ps1 down my-api                  # Stop
.\run.ps1 restart my-api               # Restart
.\run.ps1 logs my-api                  # ดู logs
.\run.ps1 shell my-api                 # เข้า container
.\run.ps1 ps                           # ดู containers ทั้งหมด
.\run.ps1 clean my-api -Deep           # ล้างทุกอย่าง
.\run.ps1 clean --all -Deep -Force     # ล้างทั้งระบบ
.\run.ps1 list                         # แสดง projects ทั้งหมด
```

### Option 2: Short Aliases (สำหรับคนขี้เกียจพิมพ์)
```powershell
# สร้าง aliases
.\r new my-api -Lang go
.\r up my-api -b      # -b = -Build
.\r down my-api
.\r logs my-api -f    # -f = follow
.\r sh my-api         # sh = shell
```

---

## 📝 Template Features

### 1. Dockerfile Templates
แต่ละภาษามี best practices ของตัวเอง:

**Go (Multi-stage for minimal size):**
```dockerfile
FROM golang:{{GO_VERSION}}-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o main .

FROM alpine:{{ALPINE_VERSION}}
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /app/main .
EXPOSE {{PORT}}
CMD ["./main"]
```

**Node (Single stage with layer optimization):**
```dockerfile
FROM node:{{NODE_VERSION}}-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE {{PORT}}
CMD ["npm", "start"]
```

**Python (With virtual env):**
```dockerfile
FROM python:{{PYTHON_VERSION}}-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE {{PORT}}
CMD ["python", "app.py"]
```

### 2. Compose Template (Universal)
```yaml
name: {{PROJECT_NAME}}

services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: {{PROJECT_NAME}}_web
    ports:
      - "${HOST_PORT:-{{DEFAULT_PORT}}}:{{CONTAINER_PORT}}"
    environment:
      - PORT={{CONTAINER_PORT}}
      - NODE_ENV=${NODE_ENV:-production}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:{{CONTAINER_PORT}}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - {{PROJECT_NAME}}_network

networks:
  {{PROJECT_NAME}}_network:
    driver: bridge
```

### 3. Port Registry (config/ports.json)
```json
{
  "reserved": {
    "8001": "py-hello",
    "8002": "go-hello",
    "8003": "node-hello"
  },
  "next_available": 8004,
  "ranges": {
    "http": "8000-8099",
    "database": "5400-5499",
    "cache": "6300-6399"
  }
}
```

---

## 🛠️ Scripts ที่ควรมี

### 1. new.ps1 - สร้าง Project จาก Template
```powershell
# scripts/new.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [Parameter(Mandatory=$true)]
    [ValidateSet('go','node','python','rust','java','php','dotnet','ruby')]
    [string]$Lang,

    [int]$Port = 0  # 0 = auto-assign
)

# 1. Check if project exists
# 2. Find available port
# 3. Copy template files
# 4. Replace placeholders ({{PROJECT_NAME}}, {{PORT}}, etc.)
# 5. Initialize git (optional)
# 6. Show next steps

# ตัวอย่างการใช้งาน:
# .\scripts\new.ps1 -Project my-rust-api -Lang rust
# .\scripts\new.ps1 -Project my-java-app -Lang java -Port 8080
```

### 2. logs.ps1 - ดู Logs
```powershell
# scripts/logs.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [switch]$Follow,      # -f for tail -f
    [int]$Tail = 100      # จำนวนบรรทัด
)

$composePath = Get-ProjectComposePath $Project
docker compose -f $composePath -p $Project logs $(if($Follow){"-f"}) --tail $Tail
```

### 3. shell.ps1 - เข้า Container Shell
```powershell
# scripts/shell.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [string]$Service = "web",
    [string]$Shell = "/bin/sh"  # or /bin/bash
)

$composePath = Get-ProjectComposePath $Project
docker compose -f $composePath -p $Project exec $Service $Shell
```

### 4. health.ps1 - ตรวจสอบสุขภาพ
```powershell
# scripts/health.ps1
param(
    [string]$Project = ""  # ถ้าไม่ระบุ = ตรวจทั้งหมด
)

# แสดง:
# - Container status
# - Health check status
# - Port mappings
# - Resource usage (CPU, Memory)
# - Uptime
```

### 5. ps.ps1 - แสดง Containers
```powershell
# scripts/ps.ps1
param(
    [switch]$All  # รวม stopped containers
)

# แสดงตารางสวยๆ ของ containers ทั้งหมด
docker ps $(if($All){"-a"}) --filter "label=com.docker.compose.project" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## 🧹 การล้างทรัพยากรแบบหมดจด

### ปรับปรุง clean.ps1 ให้ดีขึ้น

```powershell
# scripts/clean.ps1
param(
    [string]$Project = "",
    [switch]$All,      # ล้างทั้งระบบ
    [switch]$Deep,     # ล้าง images + volumes
    [switch]$Nuclear,  # ล้างทุกอย่าง (รวม builder cache, system prune)
    [switch]$Force     # ไม่ถามยืนยัน
)

# Levels of cleaning:

# Level 1: Normal (Project only)
# - Stop containers
# - Remove containers
# - Remove networks

# Level 2: Deep (Project)
# - Level 1
# - Remove project images
# - Remove project volumes
# - Remove orphaned containers

# Level 3: Nuclear (System-wide)
# - docker system prune -a --volumes --force
# - docker builder prune --all --force
# - Remove all stopped containers
# - Remove all unused images
# - Remove all unused volumes
# - Remove all unused networks
# - Clear build cache

# แสดงสิ่งที่จะลบก่อน (ถ้าไม่ -Force)
# ให้ผู้ใช้ยืนยัน Y/N
```

**ตัวอย่างการใช้:**
```powershell
# ล้าง project เดียว (ปลอดภัย)
.\run.ps1 clean my-api

# ล้าง project + images + volumes
.\run.ps1 clean my-api -Deep

# ล้างทุกอย่างในระบบ (อันตราย!)
.\run.ps1 clean --all -Nuclear -Force

# ล้างเฉพาะ stopped containers ทั้งหมด
.\run.ps1 clean --all

# ล้างรวม volumes (อันตราย สำหรับ databases)
.\run.ps1 clean --all -Deep
```

### สรุปคำสั่งล้าง Docker ทั้งหมด

```powershell
# ล้าง containers ที่ stop แล้ว
docker container prune -f

# ล้าง images ที่ไม่ได้ใช้
docker image prune -a -f

# ล้าง volumes ที่ไม่ได้ใช้ (ระวัง! ข้อมูล DB หาย)
docker volume prune -f

# ล้าง networks ที่ไม่ได้ใช้
docker network prune -f

# ล้าง build cache (ประหยัด disk มาก)
docker builder prune --all -f

# ล้างทุกอย่าง (nuclear option)
docker system prune -a --volumes -f
```

---

## 🎨 Best Practices เพิ่มเติม

### 1. Environment Variables
```
# .env.template
PROJECT_NAME={{PROJECT_NAME}}
HOST_PORT={{DEFAULT_PORT}}
CONTAINER_PORT={{CONTAINER_PORT}}

# App settings
NODE_ENV=production
LOG_LEVEL=info

# Database (if needed)
# DB_HOST=db
# DB_PORT=5432
# DB_NAME={{PROJECT_NAME}}_db
```

### 2. Health Checks
เพิ่ม health endpoint ใน template:

**Node:**
```javascript
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date() });
});
```

**Python:**
```python
@app.route('/health')
def health():
    return {'status': 'healthy', 'timestamp': datetime.now().isoformat()}
```

**Go:**
```go
http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
    json.NewEncoder(w).Encode(map[string]string{
        "status": "healthy",
        "timestamp": time.Now().Format(time.RFC3339),
    })
})
```

### 3. Logging Standards
ทุก template ควรมี structured logging:

```javascript
// Node - pino
const logger = require('pino')();
logger.info({ port: PORT }, 'Server started');
```

```python
# Python - structlog
import structlog
logger = structlog.get_logger()
logger.info("server_started", port=PORT)
```

### 4. Graceful Shutdown
```javascript
// Node
process.on('SIGTERM', () => {
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
```

---

## 📊 Monitoring & Debugging

### เพิ่ม Observability Tools (Optional)
```yaml
# docker-compose.monitoring.yml
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
```

---

## 🔧 Configuration Management

### config/defaults.json
```json
{
  "docker": {
    "restart_policy": "unless-stopped",
    "default_network_driver": "bridge",
    "health_check_interval": "30s",
    "health_check_timeout": "10s",
    "health_check_retries": 3
  },
  "ports": {
    "auto_assign_start": 8000,
    "auto_assign_end": 8999
  },
  "build": {
    "cache": true,
    "pull": true
  },
  "languages": {
    "go": {
      "version": "1.22",
      "default_port": 8080
    },
    "node": {
      "version": "20",
      "default_port": 3000
    },
    "python": {
      "version": "3.12",
      "default_port": 5000
    }
  }
}
```

---

## 📚 Documentation Template

### README.template.md (สำหรับแต่ละ project)
```markdown
# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

## Tech Stack
- Language: {{LANGUAGE}}
- Framework: {{FRAMEWORK}}
- Port: {{PORT}}

## Quick Start

### Development
\`\`\`bash
# Start
.\\run.ps1 up {{PROJECT_NAME}} -Build

# View logs
.\\run.ps1 logs {{PROJECT_NAME}} -Follow

# Enter shell
.\\run.ps1 shell {{PROJECT_NAME}}

# Stop
.\\run.ps1 down {{PROJECT_NAME}}
\`\`\`

### Testing
\`\`\`bash
curl http://localhost:{{PORT}}/
curl http://localhost:{{PORT}}/health
\`\`\`

## Structure
\`\`\`
{{PROJECT_NAME}}/
├── Dockerfile
├── compose.yml
├── {{SOURCE_FILES}}
└── README.md
\`\`\`
```

---

## ✅ Checklist การปรับปรุง

### Phase 1: Core Improvements (ควรทำก่อน)
- [ ] สร้างโฟลเดอร์ `templates/` พร้อม templates สำหรับ 5-7 ภาษา
- [ ] สร้าง `scripts/new.ps1` สำหรับสร้าง project ใหม่
- [ ] สร้าง `scripts/run.ps1` เป็น main entry point
- [ ] สร้าง `scripts/logs.ps1`, `scripts/shell.ps1`, `scripts/ps.ps1`
- [ ] ปรับปรุง `clean.ps1` ให้มี levels (normal, deep, nuclear)
- [ ] สร้าง `config/ports.json` สำหรับจัดการ ports

### Phase 2: Quality of Life (ทำตาม)
- [ ] เพิ่ม health checks ในทุก template
- [ ] เพิ่ม graceful shutdown
- [ ] สร้าง `scripts/health.ps1` ตรวจสอบสถานะ
- [ ] เพิ่ม `.env` support
- [ ] สร้าง README template

### Phase 3: Advanced Features (ถ้าต้องการ)
- [ ] Monitoring stack (Prometheus + Grafana)
- [ ] CI/CD templates
- [ ] Multi-service project templates
- [ ] Database templates (PostgreSQL, MySQL, Redis, MongoDB)
- [ ] Load balancer template (Nginx, Traefik)

---

## 🎯 ตัวอย่างการใช้งานจริง

### สร้าง Project ใหม่
```powershell
# 1. สร้าง Rust API
.\run.ps1 new my-rust-api -Lang rust
# Output: Created project at projects/my-rust-api (Port: 8004)

# 2. Start
.\run.ps1 up my-rust-api -Build
# Output: ✓ Built image, ✓ Started container, ✓ Health check passed
#         URL: http://localhost:8004

# 3. Test
curl http://localhost:8004/health

# 4. View logs
.\run.ps1 logs my-rust-api -Follow

# 5. Debug inside container
.\run.ps1 shell my-rust-api

# 6. Stop
.\run.ps1 down my-rust-api

# 7. Clean everything
.\run.ps1 clean my-rust-api -Deep -Force
```

### ล้างระบบทั้งหมด
```powershell
# ดูว่าจะลบอะไรบ้าง
.\run.ps1 clean --all -Nuclear

# ยืนยันแล้วลบ
# หรือ force เลย
.\run.ps1 clean --all -Nuclear -Force
```

---

## 💡 ประโยชน์ที่ได้รับ

1. **สร้าง project ใหม่ใน 10 วินาที** - แทนที่จะ copy-paste แล้วแก้ไขเอง
2. **คำสั่งสั้นและจำง่าย** - `.\r up myapp` แทนที่จะพิมพ์ยาวๆ
3. **Port management อัตโนมัติ** - ไม่ต้องกังวลเรื่อง port collision
4. **Clean ได้หมดจด** - มี 3 levels: normal, deep, nuclear
5. **Best practices built-in** - health checks, graceful shutdown, structured logging
6. **Template-driven** - เพิ่มภาษาใหม่ได้ง่าย เพียงเพิ่ม template
7. **Cross-platform** - PowerShell ใช้ได้ทั้ง Windows, Linux, macOS

---

## 🚧 ต่อไปนี้คือสิ่งที่ผมสามารถช่วยทำได้ทันที

1. สร้าง `scripts/run.ps1` - Main entry point
2. สร้าง `scripts/new.ps1` - Project generator
3. สร้าง templates สำหรับภาษาต่างๆ (Go, Node, Python, Rust, Java)
4. ปรับปรุง `clean.ps1` ให้มี nuclear option
5. สร้าง `logs.ps1`, `shell.ps1`, `ps.ps1`
6. สร้าง `config/ports.json` และ `config/defaults.json`

**คุณต้องการให้ผมเริ่มจากข้อไหนก่อนครับ?**
