# Multi-Compose Lab (Windows Docker Smoke Test) + Cleanup

ชุดตัวอย่างนี้ออกแบบให้ “เพิ่มโปรเจคได้เรื่อย ๆ” (หลายภาษา/หลายสแตก) และรันแยกกันได้โดยไม่ชนกัน
พร้อมสคริปต์ **ล้างพื้นที่ (cleanup)** สำหรับเครื่องที่ HDD จำกัด

## รันโปรเจค
```powershell
.\up.ps1 go-hello -Build
.\up.ps1 py-hello -Build
.\up.ps1 node-hello -Build
```

## ปิดโปรเจค (หยุด + ลบ container/network)
```powershell
.\down.ps1 go-hello
```

## ล้างพื้นที่แบบ “เฉพาะโปรเจค”
- เบา (หยุด + ลบ container/network เท่านั้น)
```powershell
.\clean.ps1 -Project go-hello
```

- ลึก (ลบ container/network + ลบ image ที่ build แบบ local ของโปรเจค + ลบ volume ของโปรเจค)
> หมายเหตุ: การลบ volume จะทำให้ข้อมูลถาวรของ service (เช่น DB) หาย
```powershell
.\clean.ps1 -Project go-hello -Deep
```

## ล้างพื้นที่แบบ “ทั้งเครื่อง” (ระวัง)
- ล้าง build cache + images ที่ไม่ถูกใช้งาน + containers ที่หยุดแล้ว (+volumes ถ้า -Deep)
```powershell
.\clean.ps1 -All
.\clean.ps1 -All -Deep
```

## เช็คพื้นที่ Docker ใช้ไปเท่าไหร่
```powershell
docker system df
docker system df -v
```

## ถ้าใช้ Docker Desktop แบบ WSL2 แล้วพื้นที่ยังไม่คืน
หลัง prune แล้วรัน:
```powershell
wsl --shutdown
```
แล้วเปิด Docker Desktop ใหม่อีกครั้ง (WSL บางครั้งจะคืนพื้นที่หลัง shutdown)
