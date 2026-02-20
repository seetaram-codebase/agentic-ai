# Update Backend URL - Quick Reference

## 📍 Current Backend URL

**Deployed Backend**: `http://54.91.39.84:8000`

**Last Updated**: February 18, 2026

---

## 🔄 How to Update Backend URL

### When ECS Task IP Changes

The ECS task public IP may change when:
- Task restarts
- Service redeploys
- Infrastructure updates

### **Step 1: Get New Backend URL**

```powershell
# Run the endpoint discovery script
.\scripts\get-ecs-endpoint.ps1
```

Or manually:
1. Go to AWS Console → ECS → rag-demo → backend → Tasks
2. Click running task
3. Copy **Public IP**

### **Step 2: Update Electron UI**

**Option A: Update .env file** (Recommended):
```bash
# Edit electron-ui/.env
VITE_API_URL=http://<NEW_IP>:8000
```

**Option B: Update client.ts directly**:
```typescript
// Edit electron-ui/src/api/client.ts
const BASE_URL = process.env.VITE_API_URL || 'http://<NEW_IP>:8000';
```

### **Step 3: Restart UI**

```powershell
# Stop current dev server (Ctrl+C)
# Then restart
cd electron-ui
npm run dev
```

---

## 🌐 Backend URL Configuration

### **For Development**:
```bash
# electron-ui/.env
VITE_API_URL=http://localhost:8000
```

### **For Production/Deployed**:
```bash
# electron-ui/.env
VITE_API_URL=http://54.91.39.84:8000  # Current ECS IP
```

### **With Load Balancer** (Future):
```bash
# electron-ui/.env
VITE_API_URL=http://rag-demo-alb-123456789.us-east-1.elb.amazonaws.com
```

---

## ✅ Verify Connection

After updating:

```bash
# Test backend health
curl http://<BACKEND_URL>:8000/health

# Test from UI
# Open browser console in Electron app
# Check network tab for API calls
```

---

## 📝 Files to Update

When backend URL changes:

1. **`electron-ui/.env`** - Primary configuration ⭐
2. **`electron-ui/src/api/client.ts`** - Default fallback URL
3. **`docs/UPDATE-BACKEND-URL.md`** - Update current URL (this file)

---

## 🔗 Related Scripts

- **Get ECS endpoint**: `.\scripts\get-ecs-endpoint.ps1`
- **Start UI**: `.\scripts\start-ui-local.bat`
- **Check prerequisites**: `.\scripts\check-prerequisites.bat`

---

## 🎯 Quick Commands

```powershell
# Get current backend URL
.\scripts\get-ecs-endpoint.ps1

# Update .env
notepad electron-ui\.env

# Restart UI
cd electron-ui
npm run dev
```

---

## ✅ Current Configuration

**Backend**: http://54.91.39.84:8000  
**API Docs**: http://54.91.39.84:8000/docs  
**Health**: http://54.91.39.84:8000/health  

**Last Verified**: February 18, 2026  
**Status**: ✅ Backend healthy and running

