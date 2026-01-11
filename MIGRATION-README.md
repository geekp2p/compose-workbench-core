# 🚀 Repo Migration Tools

เครื่องมือสำหรับย้าย repo และจัดการหลาย repos ได้ง่ายๆ

## 📋 เครื่องมือที่มี

1. **migrate-repo.ps1** - ย้าย repo ไป GitHub repo ใหม่
2. **repos-manager.ps1** - จัดการหลาย repos พร้อมกัน
3. **push-to-workbench.sh** - Push ไป repo ใดก็ได้ (Bash version)

---

## 1️⃣ migrate-repo.ps1

### การใช้งาน

#### ย้ายไป repo ใหม่ (ง่ายที่สุด)
```powershell
.\migrate-repo.ps1 -NewRepo compose-workbench-core-2
```

#### ย้ายไป repo ของคุณเอง
```powershell
.\migrate-repo.ps1 -NewRepo my-project -Owner myusername
```

#### ย้ายโดยไม่ถามยืนยัน
```powershell
.\migrate-repo.ps1 -NewRepo test-repo -Force
```

#### ใช้ Token ที่เตรียมไว้แล้ว
```powershell
$token = "ghp_xxxxxxxxxxxxx"
.\migrate-repo.ps1 -NewRepo new-repo -Token $token
```

### ฟีเจอร์

- ✅ Auto detect current branch
- ✅ รองรับ HTTPS (Token) และ SSH
- ✅ Retry logic ถ้า push ล้มเหลว (exponential backoff)
- ✅ แสดง URL ของ repo ใหม่
- ✅ ใช้งานง่าย แค่ระบุชื่อ repo

### สิ่งที่ต้องเตรียม

1. **สร้าง repo ใหม่บน GitHub**
   - ไปที่: https://github.com/new
   - ตั้งชื่อ repo (เช่น `compose-workbench-core-2`)
   - ไม่ต้อง initialize (เพราะจะ push code เข้าไป)

2. **GitHub Personal Access Token** (ถ้าใช้ HTTPS)
   - ไปที่: https://github.com/settings/tokens
   - Click: "Generate new token (classic)"
   - เลือก scope: `repo` (ทั้งหมด)
   - Copy token (เก็บไว้ดีๆ จะเห็นแค่ครั้งเดียว)

3. **SSH Key** (ถ้าใช้ SSH)
   - ดูวิธีตั้งค่า: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

---

## 2️⃣ repos-manager.ps1

จัดการหลาย repos พร้อมกัน (เช่น compose-workbench-core-1, -2, -3)

### การใช้งาน

#### แสดงรายการ repos ทั้งหมด
```powershell
.\repos-manager.ps1 -List
```

**Output:**
```
📋 Repositories

📁 compose-workbench-core [main]
   └─ clean
   Path: C:\multiprojlab\compose-workbench-core

📁 compose-workbench-core-2 [feature/new-feature]
   └─ 5 changes
   Path: C:\multiprojlab\compose-workbench-core-2

Total: 2 repo(s)
```

#### Git Status ทุก repos
```powershell
.\repos-manager.ps1 -GitStatus
```

#### Git Pull ทุก repos พร้อมกัน
```powershell
.\repos-manager.ps1 -GitPull
```

#### Git Push ทุก repos พร้อมกัน
```powershell
.\repos-manager.ps1 -GitPush
```
⚠️ จะถามยืนยันก่อน push

#### รันคำสั่งใน repos ทั้งหมด
```powershell
# Git log
.\repos-manager.ps1 -Command "git log --oneline -5"

# Docker status
.\repos-manager.ps1 -Command "docker compose ps"

# List files
.\repos-manager.ps1 -Command "ls -la"
```

#### ระบุ path และ pattern เอง
```powershell
# หา repos ใน path อื่น
.\repos-manager.ps1 -List -Path "D:\projects" -Pattern "my-project-*"

# หาทุก repo
.\repos-manager.ps1 -List -Pattern "*"
```

### ฟีเจอร์

- ✅ Auto detect repos ทั้งหมด
- ✅ รองรับ pattern matching (wildcard)
- ✅ แสดง status แต่ละ repo (branch, changes)
- ✅ Git operations (pull, push, status)
- ✅ รัน custom commands
- ✅ Retry logic สำหรับ push
- ✅ แสดง summary (success/failed counts)

### Use Cases

**1. Update ทุก repos พร้อมกัน**
```powershell
# Pull ทุก repos
.\repos-manager.ps1 -GitPull

# Check status
.\repos-manager.ps1 -GitStatus
```

**2. Deploy ทุก repos**
```powershell
# Build all
.\repos-manager.ps1 -Command "docker compose build"

# Start all
.\repos-manager.ps1 -Command ".\up.ps1 go-hello"
```

**3. Check health ทุก repos**
```powershell
.\repos-manager.ps1 -Command "docker compose ps"
```

**4. Sync ทุก repos หลัง develop**
```powershell
# Pull latest
.\repos-manager.ps1 -GitPull

# Push changes
.\repos-manager.ps1 -GitPush
```

---

## 3️⃣ push-to-workbench.sh (Bash)

Push ไป repo ใดก็ได้ (สำหรับ Linux/macOS/WSL)

### การใช้งาน

#### Push ไป compose-workbench-core (default)
```bash
./push-to-workbench.sh
```

#### Push ไป repo อื่น
```bash
./push-to-workbench.sh compose-workbench-core-2
```

#### Push ไป repo ของคุณเอง
```bash
./push-to-workbench.sh my-project myusername
```

### Parameters

```bash
./push-to-workbench.sh [repo-name] [owner]
```

- `repo-name`: ชื่อ repo (default: `compose-workbench-core`)
- `owner`: GitHub owner/org (default: `geekp2p`)

### ฟีเจอร์

- ✅ Support dynamic repo name
- ✅ รองรับ HTTPS (Token), SSH, และ Proxy
- ✅ Retry logic (exponential backoff)
- ✅ ตรวจสอบ repo ว่ามีอยู่จริง
- ✅ Branch validation

---

## 📚 Workflow Examples

### Scenario 1: ย้าย repo ไปที่ใหม่

**สถานการณ์:** อยากย้าย code จาก `compose-workbench-core` ไป `compose-workbench-core-2`

```powershell
# 1. สร้าง repo ใหม่บน GitHub
#    https://github.com/new
#    ชื่อ: compose-workbench-core-2

# 2. ย้าย code
.\migrate-repo.ps1 -NewRepo compose-workbench-core-2

# 3. ตรวจสอบ
#    เปิด: https://github.com/geekp2p/compose-workbench-core-2
```

**เสร็จแล้ว!** ✅

### Scenario 2: จัดการหลาย repos

**สถานการณ์:** มี repos 3 ตัว ต้องการ sync ทุกตัวพร้อมกัน

```powershell
# 1. ดู repos ทั้งหมด
.\repos-manager.ps1 -List

# 2. Pull ทุก repos
.\repos-manager.ps1 -GitPull

# 3. Check status
.\repos-manager.ps1 -GitStatus

# 4. Push ถ้ามี changes
.\repos-manager.ps1 -GitPush
```

### Scenario 3: Fork และ develop แยก

**สถานการณ์:** อยาก fork repo ไปพัฒนาเอง

```powershell
# 1. Fork บน GitHub
#    ไปที่ https://github.com/geekp2p/compose-workbench-core
#    Click "Fork"

# 2. Clone fork มา
git clone https://github.com/YOUR_USERNAME/compose-workbench-core.git

# 3. Develop...
#    (ทำงานปกติ)

# 4. Push กลับ fork
.\migrate-repo.ps1 -NewRepo compose-workbench-core -Owner YOUR_USERNAME
```

### Scenario 4: Testing ใน repos หลายตัว

**สถานการณ์:** ต้องการ test feature ใหม่ในหลาย repos

```powershell
# 1. List repos
.\repos-manager.ps1 -List

# 2. Run tests ทุก repos
.\repos-manager.ps1 -Command "docker compose run test"

# 3. Check results
.\repos-manager.ps1 -Command "docker compose ps"

# 4. Clean up
.\repos-manager.ps1 -Command "docker compose down -v"
```

---

## 🔧 Troubleshooting

### ❌ Error: "Repo not found"

**สาเหตร:** Repo ยังไม่มีบน GitHub

**แก้ไข:**
1. สร้าง repo: https://github.com/new
2. ตั้งชื่อให้ตรงกับที่ระบุใน command
3. ไม่ต้อง initialize (ปล่อยว่าง)
4. Run command อีกครั้ง

### ❌ Error: "Permission denied"

**สาเหตร:** ไม่มีสิทธิ์ push

**แก้ไข (HTTPS):**
1. ตรวจสอบ token: https://github.com/settings/tokens
2. Token ต้องมี scope `repo`
3. Token ยังไม่หมดอายุ

**แก้ไข (SSH):**
1. ตรวจสอบ SSH key: `ssh -T git@github.com`
2. ควรเห็น: "successfully authenticated"
3. ถ้าไม่ได้: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

### ❌ Error: "Failed after retries"

**สาเหตร:** Network issues

**แก้ไข:**
1. ตรวจสอบ internet connection
2. ลอง ping GitHub: `ping github.com`
3. ลองใช้ VPN/proxy ถ้าจำเป็น
4. Run command อีกครั้ง

### ❌ Error: "Not a git repository"

**สาเหตร:** อยู่ใน folder ที่ไม่ใช่ git repo

**แก้ไข:**
```powershell
# ไปที่ repo directory
cd C:\multiprojlab\compose-workbench-core

# ตรวจสอบว่ามี .git folder
ls -la .git

# Run command อีกครั้ง
.\migrate-repo.ps1 -NewRepo test-repo
```

---

## 💡 Tips

### 1. ใช้ aliases เพื่อความสะดวก

**PowerShell Profile** (`$PROFILE`):
```powershell
# Aliases for migration tools
function repos { .\repos-manager.ps1 @args }
function migrate { .\migrate-repo.ps1 @args }

# Examples:
# repos -List
# migrate -NewRepo new-repo
```

**Bash Profile** (`~/.bashrc` or `~/.zshrc`):
```bash
# Aliases
alias repos='pwsh -File repos-manager.ps1'
alias migrate='pwsh -File migrate-repo.ps1'
alias push-repo='./push-to-workbench.sh'
```

### 2. Environment Variables

สร้างไฟล์ `.env.migration` (git ignore):
```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
GITHUB_OWNER=geekp2p
```

Load ตอนใช้งาน:
```powershell
# PowerShell
Get-Content .env.migration | ForEach-Object {
    $name, $value = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}

.\migrate-repo.ps1 -NewRepo test -Token $env:GITHUB_TOKEN
```

### 3. Scheduled Sync

**Windows Task Scheduler:**
```powershell
# สร้าง task ที่ sync ทุกวัน
$action = New-ScheduledTaskAction -Execute "pwsh" -Argument "-File C:\multiprojlab\compose-workbench-core\repos-manager.ps1 -GitPull"
$trigger = New-ScheduledTaskTrigger -Daily -At 9AM
Register-ScheduledTask -TaskName "Sync Repos" -Action $action -Trigger $trigger
```

**Linux Cron:**
```bash
# Sync ทุกวัน 9:00
0 9 * * * cd /home/user/compose-workbench-core && pwsh -File repos-manager.ps1 -GitPull
```

### 4. Pre-push Hooks

สร้าง `.git/hooks/pre-push`:
```bash
#!/bin/bash
# Validate before push

echo "Running pre-push checks..."

# Check branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ ! $BRANCH =~ ^claude/ ]]; then
    echo "❌ Branch must start with 'claude/'"
    exit 1
fi

# Run tests
if ! docker compose run test; then
    echo "❌ Tests failed"
    exit 1
fi

echo "✅ Pre-push checks passed"
```

---

## 📚 More Help

- **README.md** - Project documentation
- **TEMPLATES.md** - Template details
- **CLAUDE.md** - Development guidelines
- **help.ps1** - Interactive help

---

## 🎯 Quick Reference

| Task | Command |
|------|---------|
| ย้าย repo | `.\migrate-repo.ps1 -NewRepo new-repo` |
| ดู repos ทั้งหมด | `.\repos-manager.ps1 -List` |
| Pull ทุก repos | `.\repos-manager.ps1 -GitPull` |
| Push ทุก repos | `.\repos-manager.ps1 -GitPush` |
| Git status ทุก repos | `.\repos-manager.ps1 -GitStatus` |
| รันคำสั่ง | `.\repos-manager.ps1 -Command "cmd"` |
| Push (Bash) | `./push-to-workbench.sh repo owner` |

---

**Happy Migrating! 🚀**
