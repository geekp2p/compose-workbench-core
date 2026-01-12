# Auto-Sync Scripts Guide

คู่มือการใช้งาน scripts สำหรับ auto-sync กับ GitHub

## 📋 สคริปต์ทั้งหมด

| Script | คำอธิบาย | Use Case |
|--------|----------|----------|
| **autosync-full.bat** | ✨ Auto commit + pull + push แบบครบวงจร | ใช้เมื่อต้องการ sync ทั้งหมดในคำสั่งเดียว |
| **auto-sync.bat** | Auto pull current branch | ใช้เมื่อต้องการ pull branch ปัจจุบัน |
| **pull_from_github.bat** | Auto pull + auto-detect latest claude/ branch | ใช้เมื่อต้องการ pull อย่างเดียว |
| **push_to_github.bat** | Auto push with retry logic | ใช้เมื่อต้องการ push อย่างเดียว |

---

## 🚀 autosync-full.bat (แนะนำ!)

**คำสั่งเดียวทำครบทุกอย่าง:** Auto commit → Pull → Push

### การใช้งาน

```batch
# แบบง่ายที่สุด - ทำทุกอย่างอัตโนมัติ
autosync-full.bat

# ระบุ remote และ branch
autosync-full.bat origin claude/my-branch

# ระบุ remote อย่างเดียว (จะ auto-detect latest claude/ branch)
autosync-full.bat origin

# ปิด auto-commit (จะถามก่อน commit)
autosync-full.bat origin "" no
```

### สิ่งที่ autosync-full.bat ทำ

**STEP 1: Auto-commit uncommitted changes**
- ✅ ตรวจสอบว่ามี uncommitted changes หรือไม่
- ✅ ถ้ามี จะ auto commit ด้วย message "Auto-sync: Update X file(s)"
- ✅ ถ้าไม่มี จะข้ามไปขั้นตอนถัดไป

**STEP 2: Auto-detect branch**
- ✅ หา latest claude/ branch จาก remote อัตโนมัติ
- ✅ เรียงลำดับตาม commit date (ใหม่สุดก่อน)
- ✅ แสดง branch date เพื่อยืนยัน
- ✅ ถ้าไม่เจอ claude/ branch จะใช้ current branch

**STEP 3: Pull from remote**
- ✅ Switch ไป branch ที่เลือกถ้ายังไม่ได้อยู่
- ✅ Fetch changes จาก remote
- ✅ แสดง summary ของ commits และ files ที่เปลี่ยน
- ✅ Pull changes ลงมา

**STEP 4: Push to remote**
- ✅ Push changes ขึ้น remote
- ✅ Retry อัตโนมัติสูงสุด 4 ครั้ง
- ✅ Exponential backoff (2s, 4s, 8s, 16s)
- ✅ แสดงความคืบหน้าของ retry

### ตัวอย่างผลลัพธ์

```
======================================
  AUTO-SYNC FULL (Pull + Push)
======================================

[STEP 1/4] Checking for uncommitted changes...
----------------------------------
Uncommitted changes detected:

 M README.md
 M AUTOSYNC-GUIDE.md
?? new-file.txt

Committing changes...
Committed successfully: Auto-sync: Update 3 file(s)

[STEP 2/4] Detecting latest branch...
----------------------------------
Fetching latest branches from origin...
Found latest claude branch: claude/auto-sync-full-abc123
Branch date: 2026-01-12 10:30:45 +0700
Target branch: claude/auto-sync-full-abc123

[STEP 3/4] Pulling from remote...
----------------------------------
Fetching from origin...
Already up to date - no remote changes.

[STEP 4/4] Pushing to remote...
----------------------------------
Pushing to origin/claude/auto-sync-full-abc123...
Pushed successfully.

======================================
  SUCCESS: Auto-sync completed!
======================================

  Remote: origin
  Branch: claude/auto-sync-full-abc123
```

---

## 📥 pull_from_github.bat

Pull changes จาก GitHub พร้อม auto-detect latest claude/ branch

### การใช้งาน

```batch
# Auto-detect latest claude/ branch และ pull
pull_from_github.bat

# Pull จาก branch ที่ระบุ
pull_from_github.bat origin claude/my-branch

# Pull จาก remote ที่ระบุ (auto-detect branch)
pull_from_github.bat origin
```

### Features

- ✅ Auto-detect latest claude/ branch จาก remote
- ✅ แสดง branch date เพื่อยืนยันว่าเป็น branch ล่าสุด
- ✅ Switch ไป branch อัตโนมัติ
- ✅ แสดง summary ของ changes
- ✅ Support custom remote URL

---

## 📤 push_to_github.bat

Push changes ขึ้น GitHub พร้อม retry logic

### การใช้งาน

```batch
# Push current branch
push_to_github.bat

# Push ไป remote และ branch ที่ระบุ
push_to_github.bat origin claude/my-branch

# Push ไป custom remote
push_to_github.bat upstream
```

### Features

- ✅ ตรวจสอบ uncommitted changes ก่อน push
- ✅ แสดง summary ของ uncommitted changes
- ✅ Auto retry สูงสุด 4 ครั้งถ้า push ล้มเหลว
- ✅ Exponential backoff (2s, 4s, 8s, 16s)
- ✅ แสดงสถานะของแต่ละ retry

---

## 🔄 auto-sync.bat

Sync current branch กับ remote tracking branch

### การใช้งาน

```batch
# Sync current branch
auto-sync.bat

# Sync กับ remote ที่ระบุ
auto-sync.bat origin
```

### Features

- ✅ Sync current branch เท่านั้น (ไม่ switch branch)
- ✅ แสดง summary ของ changes
- ✅ ตรวจสอบ uncommitted changes
- ✅ Hard reset ให้ตรงกับ remote

### ⚠️ คำเตือน

Script นี้จะทำ `git reset --hard` และ `git clean -fd`
- จะ **ลบ uncommitted changes** ทั้งหมด
- Script จะถามยืนยันก่อนถ้ามี uncommitted changes

---

## 📊 เปรียบเทียบ Scripts

| Feature | autosync-full | pull_from_github | push_to_github | auto-sync |
|---------|---------------|------------------|----------------|-----------|
| Auto commit | ✅ | ❌ | ❌ | ❌ |
| Auto pull | ✅ | ✅ | ❌ | ✅ |
| Auto push | ✅ | ❌ | ✅ | ❌ |
| Auto-detect branch | ✅ | ✅ | ❌ | ❌ |
| Retry logic | ✅ | ❌ | ✅ | ❌ |
| Switch branch | ✅ | ✅ | ❌ | ❌ |
| Safe for uncommitted changes | ✅ | ⚠️ | ✅ | ⚠️ |

---

## 💡 Use Cases

### 1. ทำงานปกติ - ต้องการ sync ทุกวัน
```batch
# ก่อนเริ่มทำงาน - pull changes ล่าสุด
pull_from_github.bat

# ... ทำงาน แก้ไขไฟล์ ...

# หลังทำงานเสร็จ - push changes
push_to_github.bat
```

### 2. ต้องการ sync แบบเร็ว - คำสั่งเดียวจบ ⚡
```batch
# ทำทุกอย่างในคำสั่งเดียว!
autosync-full.bat
```

### 3. ต้องการ sync current branch อย่างเดียว
```batch
# Sync current branch กับ remote
auto-sync.bat
```

### 4. มีหลาย branches - ต้องการเลือก branch
```batch
# Pull latest claude/ branch
pull_from_github.bat origin

# หรือ pull branch ที่ระบุ
pull_from_github.bat origin claude/specific-branch
```

### 5. Network ไม่เสถียร - ต้องการ retry
```batch
# Push พร้อม auto retry
push_to_github.bat

# หรือใช้ autosync-full ที่มี retry ในตัว
autosync-full.bat
```

---

## 🛠️ Advanced Usage

### Custom Remote URL

ถ้า remote ยังไม่ได้ตั้งค่า scripts จะใช้ default URL:
```
https://github.com/geekp2p/multi-compose-labV2.git
```

หรือระบุ URL เอง:
```batch
# Pull พร้อมตั้งค่า remote
pull_from_github.bat origin "" https://github.com/username/repo.git

# Push พร้อมตั้งค่า remote
push_to_github.bat origin "" https://github.com/username/repo.git
```

### Environment Variables

ตั้งค่า default remote URL:
```batch
set GIT_REMOTE_URL=https://github.com/username/repo.git
autosync-full.bat
```

---

## ⚙️ Configuration

### Retry Settings (push_to_github.bat, autosync-full.bat)

ปรับแต่งจำนวน retry และ delay:

```batch
rem ใน script มีตัวแปรเหล่านี้:
set MAX_RETRIES=4      rem จำนวน retry สูงสุด
set DELAY=2            rem Delay เริ่มต้น (วินาที)

rem Delay จะเพิ่มแบบ exponential:
rem Retry 1: 2s
rem Retry 2: 4s
rem Retry 3: 8s
rem Retry 4: 16s
```

### Auto-commit Message Format

ใน autosync-full.bat มี format ดังนี้:
```batch
Auto-sync: Update X file(s)
```

สามารถแก้ไข function `:auto_commit_changes` ได้:
```batch
:auto_commit_changes
...
set COMMIT_MSG=Auto-sync: Update %TOTAL_CHANGES% file(s)
rem เปลี่ยนเป็น:
rem set COMMIT_MSG=chore: auto-sync changes
...
```

---

## 🐛 Troubleshooting

### ปัญหา: "Remote does not exist"

```batch
# ตรวจสอบ remotes ที่มี
git remote -v

# เพิ่ม remote ใหม่
git remote add origin https://github.com/username/repo.git

# หรือให้ script เพิ่มให้อัตโนมัติ
autosync-full.bat origin
```

### ปัญหา: "Push failed after 4 retries"

```batch
# ตรวจสอบ network connection
ping github.com

# ตรวจสอบ authentication
git config credential.helper

# ลอง push manual
git push -u origin branch-name
```

### ปัญหา: "Uncommitted changes detected"

**ใน autosync-full.bat:**
```batch
# Script จะ auto-commit ให้อัตโนมัติ
# ถ้าไม่ต้องการ auto-commit:
autosync-full.bat origin "" no
```

**ใน auto-sync.bat:**
```batch
# จะถามยืนยันก่อนลบ changes
# ควร commit หรือ stash ก่อน:
git add .
git commit -m "Save work"
# แล้วค่อย sync
auto-sync.bat
```

### ปัญหา: "No claude/ branches found"

```batch
# ตรวจสอบว่ามี claude/ branches หรือไม่
git branch -r | findstr claude

# ถ้าไม่มี script จะใช้ current branch แทน
# หรือระบุ branch เอง:
autosync-full.bat origin main
```

---

## 📝 Best Practices

### 1. ใช้ autosync-full.bat เป็นหลัก
```batch
# Simple และทำทุกอย่างให้
autosync-full.bat
```

### 2. Commit ก่อน push เสมอ
```batch
# ✅ ดี - autosync-full จะ commit ให้อัตโนมัติ
autosync-full.bat

# ⚠️ ระวัง - ต้อง commit เอง
git add .
git commit -m "message"
push_to_github.bat
```

### 3. ตรวจสอบ changes ก่อน sync
```batch
# ดู status
git status

# ดู diff
git diff

# แล้วค่อย sync
autosync-full.bat
```

### 4. ใช้ pull ก่อนเริ่มทำงาน
```batch
# ทุกเช้าก่อนเริ่มทำงาน
pull_from_github.bat

# ... ทำงาน ...

# ก่อนกลับบ้าน
autosync-full.bat
```

### 5. Backup ก่อนใช้ auto-sync.bat
```batch
# auto-sync.bat จะทำ hard reset!
# ควร commit หรือ stash ก่อน:
git stash
auto-sync.bat
git stash pop
```

---

## 🎯 Quick Reference

```batch
# ต้องการ: sync ทุกอย่างในคำสั่งเดียว
autosync-full.bat

# ต้องการ: pull อย่างเดียว
pull_from_github.bat

# ต้องการ: push อย่างเดียว
push_to_github.bat

# ต้องการ: sync current branch (hard reset)
auto-sync.bat

# ต้องการ: pull latest claude/ branch
pull_from_github.bat origin

# ต้องการ: pull branch ที่ระบุ
pull_from_github.bat origin claude/my-branch

# ต้องการ: push พร้อม retry
push_to_github.bat origin claude/my-branch

# ต้องการ: sync พร้อม auto-commit
autosync-full.bat origin claude/my-branch

# ต้องการ: sync แต่ถามก่อน commit
autosync-full.bat origin "" no
```

---

## 📚 Related Documentation

- [README.md](README.md) - คู่มือหลักของ project
- [TEMPLATES.md](TEMPLATES.md) - Template documentation
- [CLAUDE.md](CLAUDE.md) - Development guidelines

---

## 🎉 Summary

| สถานการณ์ | คำสั่งที่แนะนำ |
|-----------|----------------|
| ทำงานปกติทุกวัน | `autosync-full.bat` |
| ต้องการ pull อย่างเดียว | `pull_from_github.bat` |
| ต้องการ push อย่างเดียว | `push_to_github.bat` |
| Sync current branch | `auto-sync.bat` |
| Network ไม่เสถียร | `autosync-full.bat` (มี retry) |
| หลาย branches | `pull_from_github.bat origin` |

**แนะนำให้ใช้ autosync-full.bat เป็นหลัก** เพราะทำทุกอย่างให้อัตโนมัติในคำสั่งเดียว! ⚡
