# Phase 6: Demo Day Preparation

## 🎯 Goal
Ensure a smooth demo with backup recording and live demo capability.

## 📋 Pre-Demo Checklist (Day Before)

### Infrastructure
- [ ] Azure OpenAI subscriptions active and tested
- [ ] Both endpoints responding (Primary + Failover)
- [ ] Chroma/Pinecone working
- [ ] Backend API running locally
- [ ] Electron app launching correctly

### Documents
- [ ] Prepare 3-5 sample PDF/TXT documents
- [ ] Documents should have interesting content for Q&A
- [ ] Test queries work well with your documents

### Demo Script
- [ ] Write out demo flow (see below)
- [ ] Practice timing (aim for 10-15 min)
- [ ] Prepare backup questions in case of issues

### Recording Setup
- [ ] OBS Studio installed and configured
- [ ] Test recording quality (1080p recommended)
- [ ] Verify audio capture works
- [ ] Do a test recording

## 🎬 Demo Script (15 minutes)

### Part 1: Introduction (2 min)
```
"Today I'm demonstrating a scalable RAG application that showcases:
- Document ingestion with Azure OpenAI embeddings
- Vector storage with Chroma/Pinecone
- Multi-subscription failover for high availability
- A desktop Electron UI for the complete experience"
```

### Part 2: Document Upload (3 min)
1. Open Electron app
2. Show empty state
3. Drag and drop sample documents
4. Show chunk count increasing
5. Explain: "The documents are being chunked and embedded using Azure OpenAI's text-embedding-ada-002 model"

### Part 3: Query Demo (4 min)
1. Ask a simple question about the documents
2. Show the response with source citations
3. Ask a more complex question
4. Highlight the provider indicator (Primary)

### Part 4: Failover Demo (4 min)
1. Show current provider status
2. Click "Trigger Failover" button
3. Watch indicator change to Secondary
4. Ask another question - shows it still works
5. Explain: "In production, this failover happens automatically on rate limits or errors"

### Part 5: Architecture Overview (2 min)
1. Show architecture diagram
2. Explain the flow:
   - Upload → S3 → SQS → Lambda → Vector DB
   - Query → API → Vector DB → Azure OpenAI → Response
3. Mention cost efficiency

## 🎥 Recording Backup

### OBS Studio Settings
```
Video:
- Base Resolution: 1920x1080
- Output Resolution: 1920x1080
- FPS: 30

Output:
- Recording Format: MP4
- Encoder: x264 (or NVENC if available)
- Rate Control: CRF
- CRF Value: 18-23

Audio:
- Sample Rate: 48kHz
- Channels: Stereo
```

### Recording Checklist
- [ ] Close unnecessary apps
- [ ] Disable notifications
- [ ] Clear desktop clutter
- [ ] Set Electron app to focused window
- [ ] Start recording BEFORE demo
- [ ] Stop recording AFTER closing demo

### Backup Recording Script
```bash
# Windows PowerShell - Start screen recording
# Option 1: Use OBS command line
& "C:\Program Files\obs-studio\bin\64bit\obs64.exe" --startrecording

# Option 2: Use built-in Xbox Game Bar
# Press Win + G, then click Record
```

## 🔥 Live Demo Tips

### Things That Can Go Wrong & Solutions

| Problem | Solution |
|---------|----------|
| API not responding | Have terminal ready to restart: `uvicorn app.main:app --reload` |
| Azure rate limit | Failover demo becomes real! Show it working |
| Electron crashes | Have web browser backup at `http://localhost:8000/docs` |
| No internet | Use pre-recorded backup video |
| Slow responses | Fill time by explaining architecture |

### Emergency Commands
```bash
# Restart backend
cd backend
uvicorn app.main:app --reload --port 8000

# Check backend health
curl http://localhost:8000/health

# Restart Electron
cd electron-ui
npm start
```

### Demo Environment Variables
Make sure `.env` is configured with real credentials:
```env
AZURE_OPENAI_ENDPOINT_1=https://your-real-endpoint-1.openai.azure.com/
AZURE_OPENAI_KEY_1=your-real-key-1
AZURE_OPENAI_ENDPOINT_2=https://your-real-endpoint-2.openai.azure.com/
AZURE_OPENAI_KEY_2=your-real-key-2
```

## 📊 Demo Metrics to Mention

- **Response Time**: ~2-3 seconds for typical queries
- **Chunk Processing**: ~50 chunks/second
- **Cost**: ~$2/hour for active demo
- **Failover Time**: <1 second automatic switch

## ✅ Demo Day Morning Checklist

```
□ Wake up early, coffee ready ☕
□ Check internet connection
□ Start backend API
□ Start Electron app
□ Upload test documents
□ Run test query
□ Verify failover works
□ Start OBS recording
□ Mute phone notifications
□ Take a deep breath 🧘
□ You've got this! 💪
```

## 🎉 Post-Demo

- Stop recording
- Save recording to cloud backup
- Note any issues for improvement
- Celebrate your success! 🎊
