# Docker Compose Templates Guide

คู่มือรายละเอียดของ **5 templates** สำหรับสร้างโปรเจค Docker ใน Multi-Compose Lab พร้อมตัวอย่างและ best practices

---

## 📋 Table of Contents

1. [Template Overview](#-template-overview)
2. [Go Template](#1-go-template)
3. [Node.js Template](#2-nodejs-template)
4. [Python Template](#3-python-template)
5. [Web Stack Template](#4-web-stack-template)
6. [Microservice Template](#5-microservice-template)
7. [Template Comparison](#-template-comparison)
8. [Creating Custom Templates](#-creating-custom-templates)
9. [Best Practices](#-best-practices)

---

## 🎨 Template Overview

| Template | Services | Complexity | Best For |
|----------|----------|------------|----------|
| **go-template** | 1 | Simple | REST APIs, Microservices |
| **node-template** | 1 | Simple | Express.js backends, Web APIs |
| **python-template** | 1 | Simple | Flask/FastAPI apps, ML services |
| **web-stack** | 3 | Medium | Full-stack web applications |
| **microservice** | 2 | Medium | Distributed systems with caching |

---

## 1. Go Template

**Use Case:** Simple REST API, Microservice, High-performance backend

### 📁 Directory Structure
```
projects/go-hello/
├── compose.yml       # Docker Compose configuration
├── Dockerfile        # Multi-stage build for Go
├── main.go          # Go application
└── go.mod           # Go modules
```

### 🐳 Dockerfile Highlights
```dockerfile
# Multi-stage build
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Minimal runtime image
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
```

**ข้อดี:**
- Image ขนาดเล็ก (< 20MB) เพราะใช้ multi-stage build
- Compile time เร็ว
- ประสิทธิภาพสูง

### 📦 Services
```yaml
name: go-hello
services:
  web:
    build: .
    ports:
      - "${HOST_PORT:-8002}:8080"
    environment:
      - PORT=8080
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 🌐 Example Endpoints
```bash
# Health check
curl http://localhost:8002/health
# {"status": "healthy"}

# Hello endpoint
curl http://localhost:8002/
# {"message": "Hello from Go!"}
```

### 🚀 การใช้งาน
```powershell
# Clone template
cp -r projects/go-hello projects/my-go-api

# แก้ port ใน compose.yml
# HOST_PORT=8010

# Build and run
.\up.ps1 my-go-api -Build

# Test
curl http://localhost:8010
```

---

## 2. Node.js Template

**Use Case:** Express.js backend, REST API, Web server

### 📁 Directory Structure
```
projects/node-hello/
├── compose.yml       # Docker Compose configuration
├── Dockerfile        # Node.js production build
├── package.json     # NPM dependencies
├── package-lock.json
└── server.js        # Express.js application
```

### 🐳 Dockerfile Highlights
```dockerfile
FROM node:18-alpine
WORKDIR /app

# Install dependencies first (caching layer)
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

EXPOSE 3000
USER node
CMD ["node", "server.js"]
```

**ข้อดี:**
- ใช้ `npm ci --only=production` เพื่อ reproducible builds
- รัน container ด้วย non-root user (`USER node`)
- Alpine image สำหรับขนาดเล็ก

### 📦 Services
```yaml
name: node-hello
services:
  web:
    build: .
    ports:
      - "${HOST_PORT:-8003}:3000"
    environment:
      - PORT=3000
      - NODE_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 🌐 Example Endpoints
```bash
# Health check
curl http://localhost:8003/health
# {"status": "ok"}

# API endpoint
curl http://localhost:8003/api/data
# {"data": [...]}
```

### 🚀 การใช้งาน
```powershell
# Clone template
cp -r projects/node-hello projects/my-express-api

# แก้ port และ environment
# Edit compose.yml: HOST_PORT=8011

# Build and run
.\up.ps1 my-express-api -Build

# Watch logs
.\service.ps1 my-express-api -Service web -Logs
```

---

## 3. Python Template

**Use Case:** Flask API, FastAPI, Machine Learning service

### 📁 Directory Structure
```
projects/py-hello/
├── compose.yml       # Docker Compose configuration
├── Dockerfile        # Python slim image
├── requirements.txt  # Python dependencies
└── app.py           # Flask application
```

### 🐳 Dockerfile Highlights
```dockerfile
FROM python:3.11-slim
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

EXPOSE 5000
USER nobody
CMD ["python", "app.py"]
```

**ข้อดี:**
- ใช้ `python:3.11-slim` แทน full image (ลด 50% ขนาด)
- `--no-cache-dir` ลดขนาด layer
- รันด้วย non-root user

### 📦 Services
```yaml
name: py-hello
services:
  web:
    build: .
    ports:
      - "${HOST_PORT:-8001}:5000"
    environment:
      - PORT=5000
      - FLASK_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 🌐 Example Endpoints
```bash
# Health check
curl http://localhost:8001/health
# {"status": "healthy"}

# ML prediction endpoint (example)
curl -X POST http://localhost:8001/predict \
  -H "Content-Type: application/json" \
  -d '{"data": [1,2,3]}'
# {"prediction": 0.95}
```

### 🚀 การใช้งาน
```powershell
# Clone template
cp -r projects/py-hello projects/my-ml-api

# เพิ่ม dependencies ใน requirements.txt
# numpy==1.24.0
# scikit-learn==1.3.0

# Build and run
.\up.ps1 my-ml-api -Build

# Test
curl http://localhost:8001
```

---

## 4. Web Stack Template

**Use Case:** Full-stack web application (Frontend + Backend + Database)

### 📁 Directory Structure
```
projects/web-stack/
├── compose.yml          # 3-service stack
├── frontend/           # Node.js React/Vue app
│   ├── Dockerfile
│   ├── package.json
│   └── src/
├── backend/            # Python FastAPI
│   ├── Dockerfile
│   ├── requirements.txt
│   └── main.py
└── .env.example        # Environment variables template
```

### 📦 Services (3 containers)
```yaml
name: web-stack
services:
  # Frontend (Node.js)
  frontend:
    build: ./frontend
    ports:
      - "${FRONTEND_PORT:-8004}:3000"
    depends_on:
      - backend
    environment:
      - VITE_API_URL=http://localhost:8005
    restart: unless-stopped

  # Backend API (Python)
  backend:
    build: ./backend
    ports:
      - "${BACKEND_PORT:-8005}:8000"
    depends_on:
      db:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
    restart: unless-stopped

  # Database (PostgreSQL)
  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  db-data:
```

### 🌐 Service Communication
```
User → Frontend (:8004) → Backend (:8005) → PostgreSQL (:5432)
```

**หมายเหตุ:** Services ภายใน compose.yml เดียวกันสื่อสารผ่าน service name:
- Frontend เรียก backend ด้วย `http://backend:8000`
- Backend เรียก database ด้วย `postgresql://db:5432`

### 🚀 การใช้งาน
```powershell
# Start ทั้ง stack
.\up.ps1 web-stack -Build

# List services
.\service.ps1 web-stack -List
# Output:
#   - frontend (healthy)
#   - backend (healthy)
#   - db (healthy)

# Restart เฉพาะ backend
.\service.ps1 web-stack -Service backend -Restart

# ดู database logs
.\service.ps1 web-stack -Service db -Logs

# เข้า database shell
docker compose -f projects/web-stack/compose.yml exec db psql -U user -d myapp

# Cleanup
.\down.ps1 web-stack
.\clean.ps1 -Project web-stack -Deep  # ลบ database volumes ด้วย
```

### 💡 Tips
- ใช้ `.env` file เพื่อจัดการ secrets
- ตั้ง `depends_on` + `condition: service_healthy` เพื่อให้ startup เป็นลำดับ
- ใช้ named volumes (`db-data`) เพื่อ persist ข้อมูล

---

## 5. Microservice Template

**Use Case:** Distributed systems, Microservices with caching layer

### 📁 Directory Structure
```
projects/microservice/
├── compose.yml          # 2-service stack with YAML anchors
├── api-service/        # Go microservice
│   ├── Dockerfile
│   ├── main.go
│   └── go.mod
└── .env.example
```

### 📦 Services (2 containers + shared config)
```yaml
name: microservice

# YAML anchors for DRY configuration
x-common-healthcheck: &common-healthcheck
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s

x-common-restart: &common-restart
  restart: unless-stopped

services:
  # API Service (Go)
  api:
    build: ./api-service
    ports:
      - "${API_PORT:-8007}:8080"
    depends_on:
      cache:
        condition: service_healthy
    environment:
      - REDIS_URL=redis://cache:6379
      - PORT=8080
    <<: *common-restart
    healthcheck:
      <<: *common-healthcheck
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]

  # Cache (Redis)
  cache:
    image: redis:7-alpine
    ports:
      - "${REDIS_PORT:-8008}:6379"
    volumes:
      - cache-data:/data
    command: redis-server --appendonly yes
    <<: *common-restart
    healthcheck:
      <<: *common-healthcheck
      test: ["CMD", "redis-cli", "ping"]

volumes:
  cache-data:
```

### 🔧 YAML Anchors Explained
```yaml
# Define reusable config
x-common-healthcheck: &common-healthcheck
  interval: 30s
  timeout: 10s

# Reuse with merge
services:
  api:
    healthcheck:
      <<: *common-healthcheck  # Merge common config
      test: ["CMD", "curl", "localhost"]  # Add specific test
```

**ข้อดี:**
- ลด duplication ด้วย YAML anchors
- Healthcheck ทุก service
- Redis persistence ด้วย appendonly mode

### 🌐 Example Usage
```bash
# API with caching
curl http://localhost:8007/api/users/123
# First call: Cache MISS → Fetch from DB → Store in Redis
# Subsequent calls: Cache HIT → Return from Redis (fast!)

# Check Redis
docker compose -f projects/microservice/compose.yml exec cache redis-cli
127.0.0.1:6379> KEYS *
1) "user:123"
127.0.0.1:6379> GET user:123
"{\"id\":123,\"name\":\"John\"}"
```

### 🚀 การใช้งาน
```powershell
# Start microservices
.\up.ps1 microservice -Build

# ทดสอบ API
curl http://localhost:8007/health

# ดู Redis stats
.\service.ps1 microservice -Service cache -Logs

# Restart เฉพาะ API
.\service.ps1 microservice -Service api -Restart

# Flush Redis cache
docker compose -f projects/microservice/compose.yml exec cache redis-cli FLUSHALL

# Cleanup
.\down.ps1 microservice
```

---

## 📊 Template Comparison

| Feature | Go | Node.js | Python | Web Stack | Microservice |
|---------|----|---------| -------|-----------|--------------|
| **Services** | 1 | 1 | 1 | 3 | 2 |
| **Languages** | Go | JavaScript | Python | JS + Python | Go |
| **Database** | ❌ | ❌ | ❌ | ✅ PostgreSQL | ❌ |
| **Caching** | ❌ | ❌ | ❌ | ❌ | ✅ Redis |
| **Multi-stage Build** | ✅ | ❌ | ❌ | ✅ | ✅ |
| **Health Checks** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **YAML Anchors** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Image Size** | ~20MB | ~180MB | ~200MB | Varies | ~30MB |
| **Startup Time** | Fast | Medium | Medium | Slow | Medium |
| **Complexity** | Low | Low | Low | Medium | Medium |

---

## 🛠️ Creating Custom Templates

### Step 1: เลือก Base Template
```powershell
# Clone template ที่ใกล้เคียงที่สุด
cp -r projects/go-hello projects/my-custom-api
```

### Step 2: แก้ compose.yml
```yaml
name: my-custom-api  # เปลี่ยนชื่อโปรเจค

services:
  web:
    build: .
    ports:
      - "${HOST_PORT:-8010}:8080"  # กำหนด port ใหม่
    environment:
      - PORT=8080
      - MY_CUSTOM_VAR=value  # เพิ่ม env vars
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Step 3: แก้ Dockerfile
```dockerfile
# ตัวอย่าง: เพิ่ม dependencies
FROM golang:1.21-alpine AS builder
WORKDIR /app

# เพิ่ม build tools
RUN apk add --no-cache git make

COPY go.* ./
RUN go mod download
COPY . .
RUN make build  # ใช้ Makefile

FROM alpine:latest
RUN apk --no-cache add ca-certificates curl
WORKDIR /root/
COPY --from=builder /app/bin/app .
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1
EXPOSE 8080
CMD ["./app"]
```

### Step 4: ทดสอบ
```powershell
# Build
.\up.ps1 my-custom-api -Build

# Test
curl http://localhost:8010/health

# ตรวจสอบ logs
.\service.ps1 my-custom-api -Service web -Logs
```

### Step 5: สร้าง Template Documentation
```markdown
# projects/my-custom-api/README.md

## My Custom API Template

**Description:** Custom Go API with advanced features

### Features
- Feature 1
- Feature 2

### Environment Variables
- `HOST_PORT` - HTTP port (default: 8010)
- `MY_CUSTOM_VAR` - Custom configuration

### Usage
\`\`\`powershell
.\up.ps1 my-custom-api -Build
curl http://localhost:8010
\`\`\`
```

---

## 📖 Best Practices

### 1. Port Management
**กฎ:** ทุกโปรเจคต้องใช้ port ไม่ซ้ำกัน

```yaml
# ใช้ environment variable
services:
  web:
    ports:
      - "${HOST_PORT:-8001}:5000"  # Default 8001, override ได้
```

**Port Allocation:**
- `8001` - Python projects
- `8002` - Go projects
- `8003` - Node.js projects
- `8004-8006` - Web Stack (frontend, backend, db)
- `8007-8008` - Microservices
- `8010+` - Custom projects

### 2. Health Checks
**ทุก service ควรมี health check:**

```yaml
services:
  web:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s  # รอ startup ก่อน
```

**Tools ที่ใช้ได้:**
- `curl` - HTTP endpoints
- `wget --spider` - Alternative to curl
- `pg_isready` - PostgreSQL
- `redis-cli ping` - Redis
- Custom script - Complex checks

### 3. Multi-Stage Builds
**สำหรับ compiled languages (Go, Rust, Java):**

```dockerfile
# Stage 1: Build
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o app .

# Stage 2: Runtime
FROM alpine:latest
COPY --from=builder /app/app .
CMD ["./app"]
```

**ประโยชน์:**
- Image ขนาดเล็กลง (ไม่มี compiler)
- ปลอดภัยกว่า (ไม่มี source code)
- Deploy เร็วขึ้น

### 4. YAML Anchors (DRY)
**ลด duplication ใน compose.yml:**

```yaml
# Define common config
x-common-logging: &common-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

x-common-healthcheck: &common-healthcheck
  interval: 30s
  timeout: 10s
  retries: 3

services:
  web:
    logging: *common-logging
    healthcheck:
      <<: *common-healthcheck
      test: ["CMD", "curl", "localhost"]

  api:
    logging: *common-logging  # Reuse
    healthcheck:
      <<: *common-healthcheck
      test: ["CMD", "wget", "localhost"]
```

### 5. Environment Variables
**ใช้ `.env` file จัดการ configuration:**

```bash
# .env
HOST_PORT=8010
DATABASE_URL=postgresql://user:pass@localhost/mydb
API_KEY=secret123
NODE_ENV=production
```

```yaml
# compose.yml
services:
  web:
    env_file: .env  # Load from file
    environment:
      - PORT=${HOST_PORT:-8080}  # Override with default
```

⚠️ **อย่า commit `.env`** - ใช้ `.env.example` แทน:
```bash
# .env.example
HOST_PORT=8010
DATABASE_URL=postgresql://user:pass@db/mydb
API_KEY=your_api_key_here
```

### 6. Dependencies Management
**ใช้ `depends_on` + `condition` สำหรับ startup order:**

```yaml
services:
  web:
    depends_on:
      db:
        condition: service_healthy  # รอจน db ready
      cache:
        condition: service_started  # รอแค่ start
    environment:
      - DATABASE_URL=postgresql://db:5432/mydb

  db:
    healthcheck:
      test: ["CMD", "pg_isready"]
      interval: 10s
```

**Conditions:**
- `service_started` - รอแค่ container start
- `service_healthy` - รอจน healthcheck pass
- `service_completed_successfully` - รอจน exit 0

### 7. Volume Management
**ใช้ named volumes สำหรับ persistent data:**

```yaml
services:
  db:
    volumes:
      - db-data:/var/lib/postgresql/data  # Named volume (persist)
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro  # Bind mount (read-only)

volumes:
  db-data:  # Managed by Docker
```

**Types:**
- **Named volumes** - จัดการโดย Docker, ปลอดภัย
- **Bind mounts** - Mount file/directory จาก host
- **tmpfs** - In-memory (ไม่ persist)

### 8. Security Best Practices

```dockerfile
# 1. ใช้ non-root user
FROM node:18-alpine
USER node  # Don't run as root
WORKDIR /home/node/app
```

```yaml
# 2. Read-only filesystem
services:
  web:
    read_only: true
    tmpfs:
      - /tmp  # Writable temp directory
```

```bash
# 3. อย่า commit secrets
echo ".env" >> .gitignore
```

---

## 📚 Additional Resources

- **[README.md](README.md)** - Quick start guide
- **[CLAUDE.md](CLAUDE.md)** - Development guidelines
- **[Docker Compose Documentation](https://docs.docker.com/compose/)** - Official docs
- **[Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/)** - Docker official guide

---

## 🤝 Contributing

พบปัญหาหรือมีข้อเสนอแนะ? เปิด issue หรือ pull request!

### เพิ่ม Template ใหม่

1. สร้างโฟลเดอร์ `projects/my-template/`
2. เพิ่ม `compose.yml`, `Dockerfile`, และโค้ด
3. ทดสอบด้วย `.\up.ps1 my-template -Build`
4. เพิ่มในตารางเปรียบเทียบ
5. อัพเดทเอกสารนี้

---

## 📜 License

[ดูไฟล์ LICENSE](LICENSE)
