# Chunker Lambda Dependencies

## Python Runtime
- **Version:** Python 3.11
- **Configured in:** `infrastructure/terraform/lambda.tf`

## Direct Dependencies (requirements-minimal.txt)

```txt
boto3>=1.34.0
langchain-community==0.3.12
langchain-text-splitters==0.3.3
pypdf==5.4.0
tiktoken>=0.5.0
```

## Transitive Dependencies (Auto-installed)

Based on the pip installation output, the following packages are also installed as dependencies:

### Core LangChain
- `langchain-core==0.3.63` - Core LangChain functionality
- `langchain==0.3.17` - Main LangChain package
- `langchain-community==0.3.12` - Document loaders (PyPDFLoader, TextLoader)
- `langchain-text-splitters==0.3.3` - Text splitting utilities

### AWS SDK
- `boto3==1.42.52` - AWS SDK for Python
- `botocore==1.42.52` - Low-level AWS SDK
- `s3transfer==0.16.0` - S3 transfer utilities

### HTTP & Async
- `httpx==0.28.1` - HTTP client
- `httpcore==1.0.9` - HTTP protocol core
- `httpx-sse==0.4.3` - Server-sent events for httpx
- `aiohttp==3.13.3` - Async HTTP client
- `aiosignal==1.4.0` - Async signal handling
- `anyio==4.12.1` - Async IO abstraction
- `h11==0.16.0` - HTTP/1.1 protocol
- `certifi==2026.1.4` - SSL certificates
- `charset-normalizer==3.4.4` - Character encoding detection
- `idna==3.11` - Internationalized domain names

### Data Processing
- `pypdf==5.4.0` - PDF parsing
- `tiktoken==0.11.0` - OpenAI tokenizer
- `numpy==2.2.6` - Numerical computing (required by tiktoken)

### Validation & Serialization
- `pydantic==2.12.5` - Data validation
- `pydantic-core==2.41.5` - Pydantic core
- `pydantic-settings==2.13.0` - Settings management
- `dataclasses-json==0.6.7` - JSON serialization for dataclasses
- `marshmallow==3.26.2` - Object serialization

### Database & ORM
- `SQLAlchemy==2.0.46` - SQL toolkit and ORM
- `greenlet==3.2.4` - Lightweight coroutines (SQLAlchemy dependency)

### LangChain Ecosystem
- `langsmith==0.2.11` - LangChain tracing/monitoring

### Utilities
- `python-dateutil==2.9.0.post0` - Date/time utilities
- `python-dotenv==1.2.1` - Environment variable loading
- `PyYAML==6.0.3` - YAML parsing
- `packaging==24.2` - Version parsing
- `requests==2.32.5` - HTTP library
- `requests-toolbelt==1.0.0` - Requests utilities
- `urllib3==2.6.3` - HTTP client
- `jmespath==1.1.0` - JSON query language (boto3 dependency)
- `jsonpatch==1.33` - JSON patch operations
- `jsonpointer==3.0.0` - JSON pointer operations
- `six==1.17.0` - Python 2/3 compatibility
- `tenacity==9.1.4` - Retry library
- `regex==2026.1.15` - Regular expressions
- `orjson==3.11.7` - Fast JSON library

### Type System
- `typing-extensions==4.15.0` - Typing backports
- `typing-inspect==0.9.0` - Runtime type inspection
- `typing-inspection==0.4.2` - Type inspection utilities
- `annotated-types==0.7.0` - Annotated type support
- `mypy-extensions==1.1.0` - MyPy extensions

### Async Collections
- `frozenlist==1.8.0` - Immutable list (aiohttp dependency)
- `multidict==6.7.1` - Multi-value dictionaries
- `yarl==1.22.0` - URL parsing
- `propcache==0.4.1` - Property caching
- `aiohappyeyeballs==2.6.1` - Happy eyeballs for asyncio
- `attrs==25.4.0` - Classes without boilerplate

## Total Package Size
Approximately **40-50 MB** when zipped (compressed)

## Key Features Used

### Document Loading (langchain-community)
```python
from langchain_community.document_loaders import PyPDFLoader, TextLoader
```
- **PyPDFLoader:** Loads PDF files page by page
- **TextLoader:** Loads plain text files with encoding support

### Text Splitting (langchain-text-splitters)
```python
from langchain.text_splitter import RecursiveCharacterTextSplitter
```
- **RecursiveCharacterTextSplitter:** Splits text intelligently by trying multiple separators
- **from_tiktoken_encoder():** Uses OpenAI's tiktoken for accurate token counting
- **Parameters:**
  - `encoding_name='cl100k_base'` (GPT-4/GPT-3.5-turbo encoding)
  - `chunk_size=1000` tokens
  - `chunk_overlap=200` tokens

### AWS Services (boto3)
```python
s3 = boto3.client('s3')
sqs = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')
```
- **S3:** Download uploaded documents
- **SQS:** Send chunks to embedding queue
- **DynamoDB:** Store document metadata

## Installation Command

```bash
pip install -r requirements-minimal.txt -t package/ \
  --platform manylinux2014_x86_64 \
  --only-binary=:all: \
  --upgrade
```

### Flags Explained:
- `-t package/` - Install to target directory
- `--platform manylinux2014_x86_64` - Build for Linux (Lambda runtime)
- `--only-binary=:all:` - Only use wheel packages (no source compilation)
- `--upgrade` - Upgrade to latest compatible versions

## Deployment Package Creation

```bash
# 1. Create package directory
mkdir package

# 2. Install dependencies
pip install -r requirements-minimal.txt -t package/ \
  --platform manylinux2014_x86_64 \
  --only-binary=:all: \
  --upgrade

# 3. Copy handler
cp handler.py package/

# 4. Create ZIP
cd package
zip -r ../chunker.zip . -x "*.pyc" -x "__pycache__/*" -x "*.dist-info/*"

# 5. Deploy to Lambda
aws lambda update-function-code \
  --function-name rag-demo-chunker \
  --zip-file fileb://chunker.zip \
  --region us-east-1
```

## Version Compatibility Notes

### Why These Versions?
- **langchain-community 0.3.12** - Latest stable with document loaders
- **langchain-text-splitters 0.3.3** - Compatible with community 0.3.12
- **langchain-core** - Auto-installed as dependency (0.3.63)
- **tiktoken latest** - For accurate token counting

### Previous Issues:
❌ **langchain-core 0.3.65** caused dependency conflict with langchain-community 0.3.12
- langchain-core 0.3.65 requires `langsmith<0.4,>=0.3.45`
- langchain-community 0.3.12 requires `langsmith<0.3,>=0.1.125`
- **Conflict!**

✅ **Solution:** Let pip auto-resolve langchain-core version by only specifying community & text-splitters

## Memory & Performance

- **Lambda Memory:** 512 MB (configurable via Terraform)
- **Lambda Timeout:** 300 seconds (5 minutes)
- **Typical Processing Time:**
  - Small PDF (1-5 pages): 2-5 seconds
  - Medium PDF (10-50 pages): 10-30 seconds
  - Large PDF (100+ pages): 1-3 minutes

## Environment Variables

```bash
DYNAMODB_DOCUMENTS_TABLE=rag-demo-documents
EMBEDDING_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/.../rag-demo-embedding
S3_BUCKET=rag-demo-documents-{account-id}
```

## Troubleshooting

### Issue: "No module named 'langchain_community'"
**Solution:** Ensure langchain-community is in requirements-minimal.txt and redeploy

### Issue: Dependency conflict
**Solution:** Don't pin langchain-core version, let it auto-resolve

### Issue: Package too large (>250MB)
**Solution:** 
- Use requirements-minimal.txt (not requirements.txt)
- Exclude test files and documentation
- Remove .dist-info directories after install

### Issue: Import errors in Lambda
**Solution:** Ensure packages are built for `manylinux2014_x86_64` platform

## Comparison: requirements.txt vs requirements-minimal.txt

### requirements.txt (Full)
- Includes ALL development dependencies
- ~100+ MB uncompressed
- May exceed Lambda size limits

### requirements-minimal.txt (Production)
- Only runtime dependencies
- ~40-50 MB compressed
- Optimized for Lambda deployment
- **This is what GitHub Actions uses**

## Last Updated
February 18, 2026

