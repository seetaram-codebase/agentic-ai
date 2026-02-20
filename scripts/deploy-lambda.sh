#!/bin/bash
# Manual Lambda Deployment Script
# Usage: ./deploy-lambda.sh [chunker|embedder|both]

set -e

FUNCTION=${1:-both}
REGION="us-east-1"

deploy_chunker() {
    echo "================================================"
    echo "Deploying Chunker Lambda"
    echo "================================================"

    cd lambda/chunker

    # Create package directory
    rm -rf package chunker-deployment.zip
    mkdir -p package

    # Install dependencies
    echo "Installing dependencies..."
    pip install -r requirements.txt -t package/

    # Copy handler
    cp handler.py package/

    # Create zip
    echo "Creating deployment package..."
    cd package
    zip -r ../chunker-deployment.zip . -q
    cd ..

    # Deploy
    echo "Deploying to AWS Lambda..."
    aws lambda update-function-code \
        --function-name rag-demo-chunker \
        --zip-file fileb://chunker-deployment.zip \
        --region $REGION

    echo "Waiting for update to complete..."
    aws lambda wait function-updated \
        --function-name rag-demo-chunker \
        --region $REGION

    echo "✅ Chunker Lambda deployed successfully!"

    cd ../..
}

deploy_embedder() {
    echo "================================================"
    echo "Deploying Embedder Lambda"
    echo "================================================"

    cd lambda/embedder

    # Create package directory
    rm -rf package embedder-deployment.zip
    mkdir -p package

    # Install dependencies
    echo "Installing dependencies..."
    pip install -r requirements.txt -t package/

    # Copy handler
    cp handler.py package/

    # Create zip
    echo "Creating deployment package..."
    cd package
    zip -r ../embedder-deployment.zip . -q
    cd ..

    # Deploy
    echo "Deploying to AWS Lambda..."
    aws lambda update-function-code \
        --function-name rag-demo-embedder \
        --zip-file fileb://embedder-deployment.zip \
        --region $REGION

    echo "Waiting for update to complete..."
    aws lambda wait function-updated \
        --function-name rag-demo-embedder \
        --region $REGION

    echo "✅ Embedder Lambda deployed successfully!"

    cd ../..
}

# Main execution
echo "================================================"
echo "RAG Demo - Lambda Deployment Script"
echo "================================================"
echo "Function: $FUNCTION"
echo "Region: $REGION"
echo ""

case $FUNCTION in
    chunker)
        deploy_chunker
        ;;
    embedder)
        deploy_embedder
        ;;
    both)
        deploy_chunker
        echo ""
        deploy_embedder
        ;;
    *)
        echo "Usage: $0 [chunker|embedder|both]"
        exit 1
        ;;
esac

echo ""
echo "================================================"
echo "✅ Deployment Complete!"
echo "================================================"
echo ""
echo "Test the deployment:"
echo "  aws logs tail /aws/lambda/rag-demo-chunker --follow"
echo "  aws logs tail /aws/lambda/rag-demo-embedder --follow"

