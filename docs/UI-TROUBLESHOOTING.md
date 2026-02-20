# UI Not Showing - Troubleshooting Guide

## 🔍 Issue: Unable to View UI

This guide helps you diagnose and fix issues with the Electron UI not starting.

---

## ⚡ Quick Fix (Try This First)

### **Step 1: Run the Startup Script**

```powershell
# Open PowerShell in the project directory
cd C:\Users\seeta\IdeaProjects\agentic-ai

# Run the startup script
.\scripts\start-ui.bat
```

This script will:
- ✅ Add Node.js to PATH automatically
- ✅ Check if npm is installed
- ✅ Install dependencies if needed
- ✅ Start the Electron UI

**Wait 10-20 seconds** - The Electron window should open automatically.

---

## 🐛 Common Issues and Solutions

### **Issue 1: "npm is not recognized"**

**Cause**: Node.js not in system PATH

**Solution A** - Temporary (for current session):
```powershell
$env:Path += ";C:\Program Files\nodejs"
cd electron-ui
npm run dev
```

**Solution B** - Permanent:
1. Restart your computer (PATH updates after restart)
2. Or manually add to PATH:
   - Right-click "This PC" → Properties
   - Advanced system settings → Environment Variables
   - Edit "Path" → Add: `C:\Program Files\nodejs`

---

### **Issue 2: Dependencies Not Installed**

**Symptoms**: 
- Error: "Cannot find module"
- Missing node_modules folder

**Solution**:
```powershell
cd C:\Users\seeta\IdeaProjects\agentic-ai\electron-ui
npm install
```

**Wait 2-3 minutes** for installation to complete.

---

### **Issue 3: Port 5173 Already in Use**

**Symptoms**:
- Error: "Port 5173 is already in use"
- UI doesn't open

**Solution**:
```powershell
# Find process using port 5173
netstat -ano | findstr :5173

# Kill the process (replace <PID> with actual PID)
taskkill /PID <PID> /F

# Try again
npm run dev
```

---

### **Issue 4: Electron Window Opens but is Blank**

**Cause**: Vite dev server not started yet

**Solution**:
- Wait 10-20 seconds for Vite to compile
- Check terminal for "Local: http://localhost:5173"
- Refresh Electron window (Ctrl+R)

---

### **Issue 5: Connection Errors in Console**

**Symptoms**:
- Electron window opens but shows errors
- Console shows: "Failed to fetch" or "Network Error"

**Check**:
1. **Is backend running?**
   ```powershell
   # Test backend
   Invoke-RestMethod http://54.91.39.84:8000/health
   ```
   Should return: `status: healthy`

2. **Is backend URL correct?**
   ```powershell
   # Check .env file
   notepad electron-ui\.env
   ```
   Should contain: `VITE_API_URL=http://54.91.39.84:8000`

---

## 📊 Manual Startup (If Script Fails)

### **Step-by-Step Manual Start**

```powershell
# Step 1: Add Node.js to PATH
$env:Path += ";C:\Program Files\nodejs"

# Step 2: Verify npm works
npm --version

# Step 3: Navigate to electron-ui
cd C:\Users\seeta\IdeaProjects\agentic-ai\electron-ui

# Step 4: Install dependencies (first time only)
npm install

# Step 5: Start development server
npm run dev
```

**Expected Output**:
```
> rag-demo-ui@1.0.0 dev
> concurrently "npm run vite" "wait-on http://localhost:5173 && electron ."

[0] 
[0] VITE v5.0.12  ready in 234 ms
[0] 
[0]   ➜  Local:   http://localhost:5173/
[1] 
[1] Electron window opening...
```

**Electron window should open in 5-10 seconds.**

---

## 🔍 Diagnostic Checks

### **1. Check Node.js Installation**

```powershell
node --version
npm --version
```

**Expected**:
- Node: v20.x.x or v24.x.x
- npm: v9.x.x or v10.x.x or v11.x.x

**If not found**: Install Node.js from https://nodejs.org/

---

### **2. Check Project Files**

```powershell
cd C:\Users\seeta\IdeaProjects\agentic-ai\electron-ui

# Check if these files exist
dir main.js
dir package.json
dir src\App.tsx
```

All should exist. If missing, re-clone the repository.

---

### **3. Check Backend Connection**

```powershell
# Test backend health
Invoke-RestMethod http://54.91.39.84:8000/health

# Test backend API docs (open in browser)
start http://54.91.39.84:8000/docs
```

Backend must be running for UI to work properly.

---

### **4. Check Firewall/Antivirus**

Sometimes Windows Defender or antivirus blocks Electron:

1. Windows Security → Virus & threat protection → Manage settings
2. Add exclusion for: `C:\Users\seeta\IdeaProjects\agentic-ai\electron-ui`

---

## 🛠️ Advanced Troubleshooting

### **Clear npm Cache**

```powershell
cd electron-ui
npm cache clean --force
rm -r node_modules
rm package-lock.json
npm install
npm run dev
```

---

### **Run Vite and Electron Separately**

This helps identify which component is failing:

**Terminal 1** - Start Vite:
```powershell
cd electron-ui
npm run vite
```

**Terminal 2** - Start Electron:
```powershell
cd electron-ui
npm start
```

---

### **Check Electron Logs**

```powershell
# Run with debug output
cd electron-ui
set DEBUG=* && npm run dev
```

Look for error messages in the output.

---

## 📝 Configuration Files to Check

### **1. electron-ui/package.json**

Should have these scripts:
```json
{
  "scripts": {
    "dev": "concurrently \"npm run vite\" \"wait-on http://localhost:5173 && electron .\"",
    "vite": "vite",
    "start": "electron ."
  }
}
```

### **2. electron-ui/.env**

Should contain:
```bash
VITE_API_URL=http://54.91.39.84:8000
```

### **3. electron-ui/vite.config.ts**

Should exist and configure Vite correctly.

---

## ✅ Success Indicators

When UI starts successfully, you should see:

**In Terminal**:
```
✔ VITE ready in X ms
➜ Local: http://localhost:5173/
Electron app ready
```

**Electron Window**:
- Opens automatically
- Shows RAG Demo UI
- No blank screen
- No console errors

**Functionality**:
- Can click "Upload Document"
- Can see chat interface
- No connection errors

---

## 🆘 Still Not Working?

### **Option 1: Use Backend Directly**

While troubleshooting UI, you can use the backend API directly:

Open browser: http://54.91.39.84:8000/docs

This gives you Swagger UI to test the API.

### **Option 2: Check Logs**

```powershell
# Check if any processes are stuck
Get-Process | Where-Object {$_.ProcessName -like "*node*" -or $_.ProcessName -like "*electron*"}

# Kill stuck processes
Stop-Process -Name node -Force
Stop-Process -Name electron -Force
```

### **Option 3: Reinstall Dependencies**

```powershell
cd electron-ui
rm -r node_modules
npm install
npm run dev
```

---

## 📞 Quick Commands Reference

```powershell
# Start UI (easiest)
.\scripts\start-ui.bat

# Manual start
$env:Path += ";C:\Program Files\nodejs"
cd electron-ui
npm run dev

# Check if running
Get-Process electron

# Stop UI
# Press Ctrl+C in terminal, or close Electron window

# Check backend
Invoke-RestMethod http://54.91.39.84:8000/health
```

---

## ✅ Expected Behavior

**Timeline**:
1. Run `npm run dev`
2. Vite compiles (5-10 seconds)
3. Electron window opens (5-10 seconds)
4. UI loads (2-3 seconds)
5. **Total**: ~15-20 seconds to fully start

**What you should see**:
- Electron window with RAG Demo interface
- Upload button visible
- Chat interface visible
- Backend connected (check console - no errors)

---

## 🎯 Next Steps After UI Starts

1. ✅ Upload a test document (`sample-docs/product-features.txt`)
2. ✅ Wait for processing (~30-60 seconds)
3. ✅ Query: "What are the main features?"
4. ✅ Get AI-powered response!

---

## 📚 Related Documentation

- **Backend Setup**: `docs/RUN-LOCALLY.md`
- **Backend URL Config**: `docs/UPDATE-BACKEND-URL.md`
- **Prerequisites**: `docs/INSTALL-PREREQUISITES.md`
- **API Usage**: `docs/API-USAGE-GUIDE.md`

