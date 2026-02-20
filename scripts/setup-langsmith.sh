#!/bin/bash
# Setup LangSmith Integration
# This script configures your LangSmith API key in AWS SSM

set -e

LANGSMITH_API_KEY="$1"
APP_NAME="${2:-rag-demo}"
AWS_REGION="${3:-us-east-1}"

if [ -z "$LANGSMITH_API_KEY" ]; then
    echo "❌ Error: LangSmith API key required"
    echo ""
    echo "Usage: ./setup-langsmith.sh <LANGSMITH_API_KEY> [APP_NAME] [AWS_REGION]"
    echo ""
    echo "Example:"
    echo "  ./setup-langsmith.sh lsv2_pt_xxxxxxxxxxxxx rag-demo us-east-1"
    echo ""
    echo "Get your LangSmith API key:"
    echo "  1. Go to https://smith.langchain.com/"
    echo "  2. Settings → API Keys"
    echo "  3. Create new API key"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          LangSmith Integration Setup                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Validate API key format
if [[ ! $LANGSMITH_API_KEY =~ ^lsv2_.* ]]; then
    echo "⚠️  Warning: API key doesn't start with 'lsv2_'"
    echo "   Are you sure this is a LangSmith API key?"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Configuration:"
echo "  App Name: $APP_NAME"
echo "  AWS Region: $AWS_REGION"
echo "  API Key: ${LANGSMITH_API_KEY:0:15}..."
echo ""

read -p "Store LangSmith API key in AWS SSM? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Step 1: Storing LangSmith API key in SSM..."
aws ssm put-parameter \
    --name "/${APP_NAME}/langsmith/api-key" \
    --value "$LANGSMITH_API_KEY" \
    --type "SecureString" \
    --region "$AWS_REGION" \
    --overwrite 2>/dev/null || \
aws ssm put-parameter \
    --name "/${APP_NAME}/langsmith/api-key" \
    --value "$LANGSMITH_API_KEY" \
    --type "SecureString" \
    --region "$AWS_REGION"

echo "✅ LangSmith API key stored in SSM"
echo ""

echo "Step 2: Verifying parameter..."
STORED_VALUE=$(aws ssm get-parameter \
    --name "/${APP_NAME}/langsmith/api-key" \
    --with-decryption \
    --region "$AWS_REGION" \
    --query 'Parameter.Value' \
    --output text)

if [ "$STORED_VALUE" == "$LANGSMITH_API_KEY" ]; then
    echo "✅ Verification successful"
else
    echo "❌ Verification failed - stored value doesn't match"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                    Setup Complete! ✅                         "
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo ""
echo "1. Deploy infrastructure with Terraform:"
echo "   cd infrastructure/terraform"
echo "   terraform apply"
echo ""
echo "2. Deploy backend (will use LangSmith automatically):"
echo "   # Trigger via GitHub Actions or manually:"
echo "   cd backend"
echo "   docker build -t backend ."
echo "   # ... deploy to ECS"
echo ""
echo "3. Make a test query:"
echo "   curl -X POST http://YOUR_ECS_IP:8000/query \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"question\": \"What is machine learning?\"}'"
echo ""
echo "4. View trace in LangSmith:"
echo "   https://smith.langchain.com/"
echo ""
echo "LangSmith is now configured for:"
echo "  ✓ ECS Backend (FastAPI)"
echo "  ✓ Embedder Lambda"
echo ""

