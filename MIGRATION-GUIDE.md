# Migration Guide: multi-compose-labV2 → compose-workbench-core

## สถานะการ Migrate

**Repository ต้นทาง:** `geekp2p/multi-compose-labV2`
**Repository ปลายทาง:** `geekp2p/compose-workbench-core`
**Branch สำหรับ Migration:** `claude/migrate-compose-workbench-G4Wud`

---

## ปัญหาที่พบ

การ push ไปยัง `compose-workbench-core` ล้มเหลวด้วย error:
```
remote: Proxy error: repository not authorized
fatal: unable to access 'http://127.0.0.1:58681/git/geekp2p/compose-workbench-core/': The requested URL returned error: 502
```

**สาเหตุ:** Repository `compose-workbench-core` ยังไม่ได้รับการอนุญาต (authorize) สำหรับ Claude Code agent ที่ทำงานผ่าน proxy

---

## วิธีแก้ปัญหา (3 ทางเลือก)

### ทางเลือกที่ 1: ใช้ GitHub CLI (gh) - แนะนำ ⭐

```bash
# 1. ตรวจสอบว่าติดตั้ง gh แล้วหรือยัง
gh --version

# 2. Login เข้า GitHub
gh auth login

# 3. Push ไปยัง compose-workbench-core
gh repo sync geekp2p/compose-workbench-core --source geekp2p/multi-compose-labV2 --branch claude/migrate-compose-workbench-G4Wud

# หรือใช้ git push ผ่าน gh
gh repo clone geekp2p/compose-workbench-core temp-workbench
cd temp-workbench
git remote add source ../multi-compose-labV2
git fetch source
git checkout -b claude/migrate-compose-workbench-G4Wud source/claude/migrate-compose-workbench-G4Wud
git push origin claude/migrate-compose-workbench-G4Wud
```

---

### ทางเลือกที่ 2: เปลี่ยน Remote Origin โดยตรง

```powershell
# 1. เปลี่ยน origin ไปชี้ที่ compose-workbench-core
git remote set-url origin https://github.com/geekp2p/compose-workbench-core.git

# 2. ตรวจสอบ
git remote -v

# 3. Push branch ปัจจุบัน
git push -u origin claude/migrate-compose-workbench-G4Wud

# 4. (Optional) เปลี่ยน origin กลับไปเดิม
git remote set-url origin https://github.com/geekp2p/multi-compose-labV2.git
```

**⚠️ หมายเหตุ:** วิธีนี้ต้องมี Git credentials ที่ถูกต้อง (HTTPS token หรือ SSH key)

---

### ทางเลือกที่ 3: ใช้ setup-repo.ps1 Script

```powershell
# 1. ใช้ script ที่มีอยู่ในโปรเจค
.\setup-repo.ps1 -NewRepoUrl "https://github.com/geekp2p/compose-workbench-core"

# 2. Script จะ:
#    - เปลี่ยน origin URL
#    - ทดสอบการเชื่อมต่อ
#    - Push ไปยัง repository ใหม่

# 3. ตรวจสอบผลลัพธ์
git remote -v
```

---

## สิ่งที่เตรียมไว้แล้ว ✅

1. **Remote workbench** ถูกเพิ่มแล้ว:
   ```
   workbench   http://local_proxy@127.0.0.1:58681/git/geekp2p/compose-workbench-core
   ```

2. **Branch** `claude/migrate-compose-workbench-G4Wud` พร้อมแล้ว:
   ```
   * claude/migrate-compose-workbench-G4Wud (clean)
   ```

3. **Repository ปลายทาง** มีอยู่จริง:
   - URL: https://github.com/geekp2p/compose-workbench-core
   - Status: Public
   - Created: 2026-01-11
   - License: AGPL-3.0

---

## ขั้นตอนที่แนะนำ

### สำหรับผู้ที่มี GitHub CLI (gh)

```bash
# เช็คว่ามี gh หรือไม่
gh --version

# ถ้ามี ใช้วิธีนี้ (ปลอดภัยที่สุด)
gh auth login
git push https://github.com/geekp2p/compose-workbench-core.git claude/migrate-compose-workbench-G4Wud
```

### สำหรับผู้ที่ใช้ HTTPS + Personal Access Token

```powershell
# 1. สร้าง Personal Access Token ที่ https://github.com/settings/tokens
#    - Scopes: repo (full control)

# 2. Push ด้วย token
git push https://<YOUR_TOKEN>@github.com/geekp2p/compose-workbench-core.git claude/migrate-compose-workbench-G4Wud
```

### สำหรับผู้ที่ใช้ SSH

```bash
# 1. เพิ่ม remote ด้วย SSH
git remote set-url workbench git@github.com:geekp2p/compose-workbench-core.git

# 2. Push
git push -u workbench claude/migrate-compose-workbench-G4Wud
```

---

## ตรวจสอบความสำเร็จ

หลังจาก push สำเร็จ ตรวจสอบที่:

1. **GitHub Web:**
   https://github.com/geekp2p/compose-workbench-core/tree/claude/migrate-compose-workbench-G4Wud

2. **Git Log:**
   ```bash
   git ls-remote workbench
   # ควรเห็น branch claude/migrate-compose-workbench-G4Wud
   ```

3. **สร้าง Pull Request:**
   ```bash
   gh pr create --repo geekp2p/compose-workbench-core \
     --base main \
     --head claude/migrate-compose-workbench-G4Wud \
     --title "Migrate multi-compose-lab to compose-workbench-core" \
     --body "Migration of all templates and scripts from multi-compose-labV2"
   ```

---

## สรุปสิ่งที่ต้องทำต่อ

1. [ ] **เลือกวิธี authentication** (gh CLI / HTTPS / SSH)
2. [ ] **Push branch** `claude/migrate-compose-workbench-G4Wud` ไปยัง `compose-workbench-core`
3. [ ] **ตรวจสอบ** บน GitHub ว่า branch ถูก push แล้ว
4. [ ] **สร้าง Pull Request** เพื่อ merge เข้า main branch
5. [ ] **อัพเดท README.md** ใน compose-workbench-core ให้สอดคล้องกับชื่อ repository ใหม่

---

## คำถามที่พบบ่อย (FAQ)

**Q: ทำไม proxy ไม่ authorize?**
A: Repository `compose-workbench-core` เพิ่งถูกสร้าง และอาจยังไม่ได้รับ permission configuration สำหรับ Claude Code agent proxy

**Q: ต้อง fork repository หรือไม่?**
A: ไม่จำเป็น ถ้าคุณมีสิทธิ์ push ไปยัง `geekp2p/compose-workbench-core` (เป็น owner หรือ collaborator)

**Q: ข้อมูลจะหายไหม?**
A: ไม่หาย เพราะ:
- Repository `multi-compose-labV2` ยังอยู่ตามเดิม
- Branch `claude/migrate-compose-workbench-G4Wud` มีอยู่ทั้ง local และ remote (origin)
- การ push เป็นการ copy ไป repository ปลายทาง ไม่ใช่ย้าย

**Q: ควร merge branch นี้เข้า main หรือไม่?**
A: ขึ้นอยู่กับการออกแบบ:
- ถ้า `compose-workbench-core` ควรมี content เหมือน `multi-compose-labV2` → ควร merge
- ถ้าต้องการ review ก่อน → สร้าง PR แล้ว review บน GitHub

---

## ติดต่อ / ขอความช่วยเหลือ

ถ้ายังมีปัญหา ให้:
1. ตรวจสอบ Git credentials: `git config --list | grep credential`
2. ทดสอบการเชื่อมต่อ: `ssh -T git@github.com` (ถ้าใช้ SSH)
3. เช็ค GitHub permissions: https://github.com/settings/tokens
