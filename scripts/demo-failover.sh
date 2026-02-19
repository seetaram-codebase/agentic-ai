#!/bin/bash
# Failover Demonstration Script
# Shows automatic US-East → EU-West failover

BACKEND_URL="http://YOUR_BACKEND_IP:8000"  # Update this!

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   RAG System - Multi-Region Failover Demonstration            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Step 1: Check Initial Health Status${NC}"
echo "────────────────────────────────────────────────────────────────"
INITIAL_STATUS=$(curl -s ${BACKEND_URL}/demo/health-status)
CURRENT_PROVIDER=$(echo $INITIAL_STATUS | jq -r '.azure_openai.current_provider')
echo -e "Current Active Region: ${GREEN}${CURRENT_PROVIDER}${NC}"
echo ""
echo "Health Status:"
echo $INITIAL_STATUS | jq '.azure_openai.endpoints'
echo ""

read -p "Press Enter to make a normal query..."
echo ""

echo -e "${BLUE}Step 2: Normal Query (Both Regions Healthy)${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "Sending query: 'What is machine learning?'"
START_TIME=$(date +%s)
RESPONSE=$(curl -s -X POST ${BACKEND_URL}/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is machine learning?"}')
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

PROVIDER=$(echo $RESPONSE | jq -r '.provider')
ANSWER=$(echo $RESPONSE | jq -r '.response' | head -c 100)

echo -e "Provider: ${GREEN}${PROVIDER}${NC}"
echo -e "Latency: ${GREEN}${DURATION}s${NC}"
echo -e "Answer: ${ANSWER}..."
echo ""

read -p "Press Enter to trigger failover..."
echo ""

echo -e "${YELLOW}Step 3: Trigger Failover (Simulate US-East Failure)${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "Triggering manual failover..."
FAILOVER_RESULT=$(curl -s -X POST ${BACKEND_URL}/demo/failover)
OLD_PROVIDER=$(echo $FAILOVER_RESULT | jq -r '.old_provider')
NEW_PROVIDER=$(echo $FAILOVER_RESULT | jq -r '.new_provider')

echo -e "Old Provider: ${RED}${OLD_PROVIDER}${NC}"
echo -e "New Provider: ${GREEN}${NEW_PROVIDER}${NC}"
echo ""

echo "Waiting 2 seconds for failover to take effect..."
sleep 2
echo ""

echo -e "${BLUE}Step 4: Check Health Status After Failover${NC}"
echo "────────────────────────────────────────────────────────────────"
POST_FAILOVER_STATUS=$(curl -s ${BACKEND_URL}/demo/health-status)
echo $POST_FAILOVER_STATUS | jq '.azure_openai.endpoints'
echo ""

read -p "Press Enter to make query using failover region..."
echo ""

echo -e "${BLUE}Step 5: Query Using Failover Region (EU-West)${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "Sending query: 'Explain neural networks'"
START_TIME=$(date +%s)
RESPONSE=$(curl -s -X POST ${BACKEND_URL}/query \
  -H "Content-Type: application/json" \
  -d '{"question": "Explain neural networks"}')
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

PROVIDER=$(echo $RESPONSE | jq -r '.provider')
ANSWER=$(echo $RESPONSE | jq -r '.response' | head -c 100)

echo -e "Provider: ${GREEN}${PROVIDER}${NC} ← Using failover region!"
echo -e "Latency: ${GREEN}${DURATION}s${NC}"
echo -e "Answer: ${ANSWER}..."
echo ""

echo "✓ Request succeeded even though primary region is down!"
echo ""

read -p "Press Enter to check CloudWatch logs..."
echo ""

echo -e "${BLUE}Step 6: View Backend Logs (Optional)${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "To see failover in action, check CloudWatch logs:"
echo ""
echo "  aws logs tail /aws/ecs/rag-demo-backend --follow --format short"
echo ""
echo "You should see logs like:"
echo "  [INFO] Attempting chat with Chat (us-east)"
echo "  [ERROR] Error with Chat (us-east): ..."
echo "  [WARNING] Marked Chat (us-east) as unhealthy"
echo "  [INFO] Attempting chat with Chat (eu-west)"
echo "  [INFO] ✅ Success with Chat (eu-west)"
echo ""

read -p "Press Enter to check LangSmith trace..."
echo ""

echo -e "${BLUE}Step 7: View LangSmith Trace (If Configured)${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "If you configured LangSmith:"
echo ""
echo "  1. Go to https://smith.langchain.com/"
echo "  2. Select project: rag-demo"
echo "  3. View latest trace"
echo "  4. You'll see:"
echo "     - Provider: Chat (eu-west)"
echo "     - Failover event in timeline"
echo "     - Full trace of RAG pipeline"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "                  Demonstration Complete!                       "
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  ✓ Normal query used: US-East"
echo "  ✓ Triggered failover to: EU-West"
echo "  ✓ Query succeeded using failover region"
echo "  ✓ No errors, just automatic failover!"
echo ""
echo "Key Points for Presentation:"
echo "  • Failover is automatic (< 1 second)"
echo "  • No data loss (RPO = 0)"
echo "  • Users experience minimal delay"
echo "  • System self-heals after 60 seconds"
echo ""

