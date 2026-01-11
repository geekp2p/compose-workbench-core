# Repository Setup Guide

คู่มือสำหรับการตั้งค่า Git Repository เพื่อนำโปรเจคนี้ไปใช้กับ repository ของตัวเอง

---

## 📋 สารบัญ

1. [เริ่มต้นใช้งานครั้งแรก (First Time Setup)](#เริ่มต้นใช้งานครั้งแรก-first-time-setup)
2. [เปลี่ยน Repository ปลายทาง](#เปลี่ยน-repository-ปลายทาง)
3. [Authentication Methods](#authentication-methods)
4. [Git Operations ที่ใช้บ่อย](#git-operations-ที่ใช้บ่อย)
5. [Troubleshooting](#troubleshooting)

---

## 🚀 เริ่มต้นใช้งานครั้งแรก (First Time Setup)

### สถานการณ์ที่ 1: Clone โปรเจคนี้มาใช้งาน

```powershell
# 1. Clone repository ต้นฉบับ
git clone https://github.com/geekp2p/multi-compose-labV2.git my-project
cd my-project

# 2. ตั้งค่า Git user ของคุณ
git config user.name "Your Name"
git config user.email "your.email@example.com"

# 3. สร้าง repository ใหม่บน GitHub (ทำผ่าน Web UI)
# https://github.com/new

# 4. เปลี่ยน remote ไปยัง repository ใหม่ของคุณ
.\setup-repo.ps1 -NewRepoUrl "https://github.com/your-username/your-repo-name"

# 5. Push โปรเจคไปยัง repository ใหม่
git push -u origin main
```

### สถานการณ์ที่ 2: เริ่มต้นโปรเจคใหม่จาก Template

```powershell
# 1. Download ZIP จาก GitHub
# https://github.com/geekp2p/multi-compose-labV2/archive/refs/heads/main.zip

# 2. Extract ไปยังโฟลเดอร์ที่ต้องการ
# 3. เปิด PowerShell ในโฟลเดอร์นั้น

# 4. Initialize Git
git init
git add .
git commit -m "Initial commit from multi-compose-lab template"

# 5. สร้าง repository บน GitHub
# https://github.com/new

# 6. ตั้งค่า remote และ push
.\setup-repo.ps1 -NewRepoUrl "https://github.com/your-username/your-repo-name"
git push -u origin main
```

---

## 🔄 เปลี่ยน Repository ปลายทาง

### ใช้ setup-repo.ps1 (แนะนำ)

```powershell
# ดูการตั้งค่าปัจจุบัน
.\setup-repo.ps1 -ShowCurrent

# เปลี่ยนไปยัง repository ใหม่ (HTTPS)
.\setup-repo.ps1 -NewRepoUrl "https://github.com/username/new-repo"

# เปลี่ยนไปยัง repository ใหม่ (SSH)
.\setup-repo.ps1 -NewRepoUrl "git@github.com:username/new-repo.git" -Method ssh

# ทดสอบการเชื่อมต่อ
.\setup-repo.ps1 -TestConnection
```

### ใช้คำสั่ง Git โดยตรง

```powershell
# ดู remote ปัจจุบัน
git remote -v

# เปลี่ยน remote URL
git remote set-url origin https://github.com/username/new-repo.git

# หรือลบและเพิ่มใหม่
git remote remove origin
git remote add origin https://github.com/username/new-repo.git

# ตั้งค่า upstream branch
git push -u origin main
```

---

## 🔐 Authentication Methods

### Method 1: HTTPS (แนะนำสำหรับผู้เริ่มต้น)

**ข้อดี:**
- ตั้งค่าง่าย
- ทำงานได้กับ firewall/proxy
- ไม่ต้องจัดการ SSH keys

**ข้อเสีย:**
- ต้องใช้ Personal Access Token (PAT) แทน password
- อาจต้องกรอก credentials บ่อย

**การตั้งค่า:**

```powershell
# 1. ตั้งค่า repository ด้วย HTTPS URL
.\setup-repo.ps1 -NewRepoUrl "https://github.com/username/repo-name"

# 2. สร้าง Personal Access Token (PAT) บน GitHub
#    - ไปที่: Settings → Developer settings → Personal access tokens → Tokens (classic)
#    - กด "Generate new token (classic)"
#    - เลือก scopes: repo (full control of private repositories)
#    - คัดลอก token ที่ได้

# 3. ครั้งแรกที่ push/pull Git จะถาม username และ password
git push -u origin main
# Username: your-github-username
# Password: <paste-your-PAT-here>

# 4. Credential helper จะจำ PAT ให้ (ไม่ต้องกรอกอีก)
```

**Credential Helper:**

```powershell
# Windows (ใช้ Windows Credential Manager)
git config --global credential.helper wincred

# Linux (เก็บใน ~/.git-credentials)
git config --global credential.helper store

# Linux (เก็บใน memory 15 นาที)
git config --global credential.helper cache
git config --global credential.helper 'cache --timeout=3600'  # 1 hour
```

### Method 2: SSH (แนะนำสำหรับ Advanced Users)

**ข้อดี:**
- ปลอดภัยกว่า
- ไม่ต้องกรอก credentials
- ใช้งานได้กับหลาย repositories

**ข้อเสีย:**
- ตั้งค่ายุ่งยากกว่า
- อาจไม่ทำงานกับบาง firewall/proxy

**การตั้งค่า:**

```powershell
# 1. ตรวจสอบว่ามี SSH key หรือยัง
ls ~/.ssh
# มองหา: id_ed25519, id_ed25519.pub (หรือ id_rsa, id_rsa.pub)

# 2. ถ้ายังไม่มี ให้สร้างใหม่
ssh-keygen -t ed25519 -C "your.email@example.com"
# กด Enter 3 ครั้ง (ใช้ค่า default)

# 3. Start SSH agent
# Windows (PowerShell as Admin):
Start-Service ssh-agent
Set-Service ssh-agent -StartupType Automatic

# Linux/Mac:
eval "$(ssh-agent -s)"

# 4. เพิ่ม SSH key ใน agent
ssh-add ~/.ssh/id_ed25519

# 5. คัดลอก public key
# Windows:
Get-Content ~/.ssh/id_ed25519.pub | Set-Clipboard

# Linux/Mac:
cat ~/.ssh/id_ed25519.pub
# แล้วคัดลอกเอง

# 6. เพิ่ม SSH key บน GitHub
#    - ไปที่: Settings → SSH and GPG keys → New SSH key
#    - Paste public key ที่คัดลอกไว้
#    - กด "Add SSH key"

# 7. ทดสอบการเชื่อมต่อ
ssh -T git@github.com
# ควรเห็น: "Hi username! You've successfully authenticated..."

# 8. ตั้งค่า repository ด้วย SSH URL
.\setup-repo.ps1 -NewRepoUrl "git@github.com:username/repo-name.git" -Method ssh

# 9. Push ได้เลย (ไม่ต้องกรอก credentials)
git push -u origin main
```

---

## 🔧 Git Operations ที่ใช้บ่อย

### ใช้ git-helper.ps1 (ง่ายและสะดวก)

```powershell
# ดูสถานะปัจจุบัน
.\git-helper.ps1 -Status

# Pull ล่าสุดจาก remote
.\git-helper.ps1 -Pull

# Commit การเปลี่ยนแปลง
.\git-helper.ps1 -Commit -Message "Add new feature"

# Push ไปยัง remote
.\git-helper.ps1 -Push

# ทำทั้งหมดในคำสั่งเดียว (Pull → Commit → Push)
.\git-helper.ps1 -Sync -Message "Update documentation"

# จัดการ branches
.\git-helper.ps1 -List                    # ดู branches ทั้งหมด
.\git-helper.ps1 -Branch main             # สลับไปยัง branch main
.\git-helper.ps1 -NewBranch feature/new   # สร้าง branch ใหม่

# ดูประวัติ commits
.\git-helper.ps1 -Log

# ดูข้อมูล remote
.\git-helper.ps1 -Remote
```

### ใช้ Git โดยตรง

```powershell
# Basic workflow
git status                              # ดูสถานะ
git add .                               # เพิ่มไฟล์ทั้งหมด
git commit -m "Your message"            # Commit
git push                                # Push ไปยัง remote

# Branch management
git branch                              # ดู branches
git checkout -b feature/new             # สร้าง branch ใหม่
git checkout main                       # สลับไปยัง branch main
git merge feature/new                   # Merge branch

# Remote operations
git pull                                # Pull จาก remote
git push -u origin main                 # Push และตั้ง upstream
git fetch                               # Fetch จาก remote (ไม่ merge)

# View history
git log --oneline --graph --decorate    # ดูประวัติแบบกราฟ
git diff                                # ดูการเปลี่ยนแปลง
```

---

## 📦 Workflows

### Workflow 1: Daily Development

```powershell
# เช้า: Pull ล่าสุด
.\git-helper.ps1 -Pull

# ทำงาน... แก้โค้ด... ทดสอบ...

# เย็น: Commit และ Push
.\git-helper.ps1 -Sync -Message "Implement user authentication"
```

### Workflow 2: Feature Development

```powershell
# 1. สร้าง feature branch
.\git-helper.ps1 -NewBranch feature/user-auth

# 2. พัฒนา feature... แก้โค้ด...

# 3. Commit เป็นระยะ
.\git-helper.ps1 -Commit -Message "Add login form"
.\git-helper.ps1 -Commit -Message "Add authentication logic"

# 4. Push feature branch
git push -u origin feature/user-auth

# 5. สร้าง Pull Request บน GitHub
# 6. หลัง merge แล้ว กลับไปยัง main
.\git-helper.ps1 -Branch main
.\git-helper.ps1 -Pull
```

### Workflow 3: Multiple Developers

```powershell
# Developer 1:
.\git-helper.ps1 -NewBranch feature/frontend
# ... ทำงาน ...
.\git-helper.ps1 -Push
git push -u origin feature/frontend

# Developer 2:
.\git-helper.ps1 -NewBranch feature/backend
# ... ทำงาน ...
.\git-helper.ps1 -Push
git push -u origin feature/backend

# Merge on GitHub via Pull Requests
# แล้ว developers ทั้งคู่ pull ล่าสุด:
.\git-helper.ps1 -Branch main
.\git-helper.ps1 -Pull
```

### Workflow 4: Hotfix

```powershell
# 1. สร้าง hotfix branch จาก main
.\git-helper.ps1 -Branch main
.\git-helper.ps1 -Pull
.\git-helper.ps1 -NewBranch hotfix/critical-bug

# 2. แก้บั๊ก
# ... แก้โค้ด ...

# 3. Commit และ Push
.\git-helper.ps1 -Commit -Message "Fix critical bug in login"
git push -u origin hotfix/critical-bug

# 4. สร้าง Pull Request และ merge ทันที
# 5. Pull ล่าสุด
.\git-helper.ps1 -Branch main
.\git-helper.ps1 -Pull
```

---

## 🔄 การย้าย Repository

### สถานการณ์: ย้ายจาก GitHub A → GitHub B

```powershell
# 1. Clone repository เดิม
git clone https://github.com/old-org/old-repo.git
cd old-repo

# 2. สร้าง repository ใหม่บน GitHub B
# https://github.com/new-org/new-repo

# 3. เปลี่ยน remote
.\setup-repo.ps1 -NewRepoUrl "https://github.com/new-org/new-repo"

# 4. Push ทั้งหมด
git push -u origin --all       # Push all branches
git push -u origin --tags      # Push all tags

# 5. ตรวจสอบ
.\setup-repo.ps1 -ShowCurrent
```

### สถานการณ์: Fork และปรับแต่ง

```powershell
# 1. Fork บน GitHub (กดปุ่ม Fork)

# 2. Clone fork ของคุณ
git clone https://github.com/your-username/multi-compose-labV2.git
cd multi-compose-labV2

# 3. เพิ่ม upstream remote (ต้นฉบับ)
git remote add upstream https://github.com/geekp2p/multi-compose-labV2.git

# 4. ดู remotes
git remote -v
# origin    https://github.com/your-username/multi-compose-labV2.git (fetch)
# origin    https://github.com/your-username/multi-compose-labV2.git (push)
# upstream  https://github.com/geekp2p/multi-compose-labV2.git (fetch)
# upstream  https://github.com/geekp2p/multi-compose-labV2.git (push)

# 5. Pull updates จากต้นฉบับ
git fetch upstream
git merge upstream/main

# 6. Push ไปยัง fork ของคุณ
git push origin main
```

---

## ❓ Troubleshooting

### ปัญหา: Authentication Failed (HTTPS)

```powershell
# อาการ: Username/Password ไม่ถูกต้อง
# remote: Support for password authentication was removed...

# สาเหตุ: GitHub ไม่รองรับ password แล้ว ต้องใช้ PAT

# แก้ไข:
# 1. สร้าง Personal Access Token (PAT)
#    Settings → Developer settings → Personal access tokens → Generate new token
# 2. ใช้ PAT แทน password
# 3. หรือเปลี่ยนเป็น SSH
```

### ปัญหา: SSH Connection Failed

```powershell
# อาการ: Permission denied (publickey)

# แก้ไข:
# 1. ตรวจสอบว่ามี SSH key
ls ~/.ssh

# 2. สร้างใหม่ถ้าไม่มี
ssh-keygen -t ed25519 -C "your.email@example.com"

# 3. เพิ่ม key ใน agent
ssh-add ~/.ssh/id_ed25519

# 4. เพิ่ม public key บน GitHub
cat ~/.ssh/id_ed25519.pub  # คัดลอกและเพิ่มบน GitHub

# 5. ทดสอบ
ssh -T git@github.com
```

### ปัญหา: Push Rejected

```powershell
# อาการ: ! [rejected] main -> main (fetch first)

# สาเหตุ: Remote มีการเปลี่ยนแปลงที่คุณยัง pull ไม่มา

# แก้ไข:
git pull --rebase
git push
```

### ปัญหา: Merge Conflicts

```powershell
# อาการ: CONFLICT (content): Merge conflict in <file>

# แก้ไข:
# 1. เปิดไฟล์ที่ขัดแย้ง
# 2. แก้ไขส่วน conflict markers (<<<<<<, =======, >>>>>>>)
# 3. เก็บโค้ดที่ต้องการ
# 4. Stage และ commit
git add .
git commit -m "Resolve merge conflicts"
git push
```

### ปัญหา: Wrong Remote URL

```powershell
# อาการ: Push ไปผิด repository

# แก้ไข:
.\setup-repo.ps1 -ShowCurrent  # ดู remote ปัจจุบัน
.\setup-repo.ps1 -NewRepoUrl "https://github.com/correct-user/correct-repo"
```

### ปัญหา: Credential Prompt ทุกครั้ง (HTTPS)

```powershell
# อาการ: ถาม username/password ทุกครั้งที่ push/pull

# แก้ไข Windows:
git config --global credential.helper wincred

# แก้ไข Linux:
git config --global credential.helper store
# หรือ
git config --global credential.helper 'cache --timeout=3600'

# หรือเปลี่ยนเป็น SSH:
.\setup-repo.ps1 -NewRepoUrl "git@github.com:user/repo.git" -Method ssh
```

### ปัญหา: Large Files (>100MB)

```powershell
# อาการ: error: GH001: Large files detected

# แก้ไข:
# 1. ใช้ Git LFS (Large File Storage)
git lfs install
git lfs track "*.zip"
git lfs track "*.tar.gz"
git add .gitattributes
git commit -m "Add Git LFS tracking"

# 2. หรือลบไฟล์ขนาดใหญ่
git rm --cached large-file.zip
git commit -m "Remove large file"
```

---

## 🎯 Best Practices

### 1. Commit Messages

```powershell
# ✓ ดี: ชัดเจน กระชับ บอกเหตุผล
git commit -m "Fix login bug: handle empty username"
git commit -m "Add user authentication with JWT"
git commit -m "Update README: add installation instructions"

# ✗ ไม่ดี: คลุมเครือ ไม่มีรายละเอียด
git commit -m "fix"
git commit -m "update"
git commit -m "changes"
```

### 2. Branch Naming

```powershell
# ✓ ดี: มีโครงสร้าง บอกประเภท
feature/user-authentication
bugfix/login-error
hotfix/critical-security-patch
docs/update-readme
refactor/database-layer

# ✗ ไม่ดี: ไม่มีโครงสร้า ไม่ชัดเจน
new-stuff
fix1
test
```

### 3. Pull Before Push

```powershell
# ✓ ดี: Pull ก่อนเสมอ
git pull
git push

# หรือใช้:
.\git-helper.ps1 -Sync -Message "Update"

# ✗ ไม่ดี: Push โดยไม่ pull ก่อน
git push  # อาจเกิด conflict
```

### 4. Use .gitignore

```powershell
# เพิ่มไฟล์ที่ไม่ต้องการ commit
echo "node_modules/" >> .gitignore
echo "*.log" >> .gitignore
echo ".env" >> .gitignore
echo ".DS_Store" >> .gitignore

git add .gitignore
git commit -m "Update .gitignore"
```

### 5. Regular Commits

```powershell
# ✓ ดี: Commit บ่อยๆ เป็นระยะ
.\git-helper.ps1 -Commit -Message "Add login form HTML"
.\git-helper.ps1 -Commit -Message "Add login validation"
.\git-helper.ps1 -Commit -Message "Add login API endpoint"

# ✗ ไม่ดี: Commit ครั้งเดียว ทำงานหลายอย่าง
.\git-helper.ps1 -Commit -Message "Add entire authentication system"
```

---

## 📚 Resources

### GitHub Documentation
- [GitHub Docs](https://docs.github.com/)
- [Creating a Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [Connecting to GitHub with SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)

### Git Documentation
- [Git Documentation](https://git-scm.com/doc)
- [Pro Git Book](https://git-scm.com/book/en/v2)

### Tools
- **setup-repo.ps1** - ตั้งค่า repository และ authentication
- **git-helper.ps1** - Git operations ที่ใช้บ่อย
- [GitHub Desktop](https://desktop.github.com/) - GUI สำหรับ Git
- [GitKraken](https://www.gitkraken.com/) - Advanced Git GUI

---

## 🆘 Need Help?

### Quick Reference

```powershell
# Repository Setup
.\setup-repo.ps1 -ShowCurrent              # ดูการตั้งค่าปัจจุบัน
.\setup-repo.ps1 -TestConnection           # ทดสอบการเชื่อมต่อ
.\setup-repo.ps1 -NewRepoUrl <url>         # เปลี่ยน repository

# Git Operations
.\git-helper.ps1 -Status                   # ดูสถานะ
.\git-helper.ps1 -Pull                     # Pull
.\git-helper.ps1 -Commit -Message "msg"    # Commit
.\git-helper.ps1 -Push                     # Push
.\git-helper.ps1 -Sync -Message "msg"      # Pull + Commit + Push

# Branch Management
.\git-helper.ps1 -List                     # ดู branches
.\git-helper.ps1 -Branch main              # สลับ branch
.\git-helper.ps1 -NewBranch feature/new    # สร้าง branch ใหม่
```

### Common Commands Cheatsheet

```powershell
# Setup
git config user.name "Name"
git config user.email "email"
git remote -v
git remote set-url origin <url>

# Daily Use
git status
git add .
git commit -m "message"
git push
git pull

# Branches
git branch
git checkout -b feature/new
git checkout main
git merge feature/new

# History
git log --oneline
git log --graph --decorate
git diff

# Undo
git reset HEAD~1              # Undo last commit (keep changes)
git reset --hard HEAD~1       # Undo last commit (discard changes)
git checkout -- <file>        # Discard changes in file
```

---

**หมายเหตุ:** ถ้ามีคำถามหรือปัญหา สามารถ:
1. ดู [README.md](README.md) สำหรับข้อมูลโปรเจค
2. ดู [CLAUDE.md](CLAUDE.md) สำหรับ development guidelines
3. เปิด issue บน GitHub repository
