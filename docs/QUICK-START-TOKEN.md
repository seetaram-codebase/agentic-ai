# Quick Start: Generate TF_API_TOKEN

## 🚀 5-Minute Guide

### Step 1: Go to Terraform Cloud Tokens Page
**Direct Link**: [https://app.terraform.io/app/settings/tokens](https://app.terraform.io/app/settings/tokens)

Or manually:
1. Log in to [https://app.terraform.io](https://app.terraform.io)
2. Click your profile icon (top right)
3. Select "User Settings"
4. Click "Tokens" in the left sidebar

---

### Step 2: Create New Token

Click the **"Create an API token"** button

Fill in:
- **Description**: `GitHub Actions CI/CD` (or your preferred name)
- **Expiration**: `30 days` (recommended for testing)

Click **"Generate token"**

---

### Step 3: Copy the Token ⚠️

**IMPORTANT**: You can only see this token ONCE!

The token will look like:
```
github-actions.atlasv1.aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890...
```

**Copy it immediately!** Save it somewhere secure temporarily.

---

### Step 4: Add to GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** tab
3. In left sidebar: **Secrets and variables** → **Actions**
4. Click **"New repository secret"**
5. Enter:
   - Name: `TF_API_TOKEN`
   - Secret: (paste the token you copied)
6. Click **"Add secret"**

---

### Step 5: Verify Setup ✅

Run this test:

1. Go to **Actions** tab in your GitHub repo
2. Select **"Deploy Full Stack"** workflow
3. Click **"Run workflow"**
4. Select:
   - Environment: `dev`
   - Terraform action: `plan` (safe test)
   - Deploy infrastructure: ✅
5. Click **"Run workflow"**

If it runs without authentication errors, you're all set! ✅

---

## 🆘 Quick Troubleshooting

### ❌ Error: "Invalid credentials"
- **Fix**: Regenerate the token and update GitHub Secret

### ❌ Error: "Organization not found"
- **Fix**: Check `infrastructure/terraform/providers.tf` has correct org name: `agentic-ai-org`

### ❌ Token not working
- **Fix**: Ensure no extra spaces when copying/pasting
- **Fix**: Verify secret name is exactly `TF_API_TOKEN` (case-sensitive)

---

## 📋 Quick Checklist

- [ ] Generated token at https://app.terraform.io/app/settings/tokens
- [ ] Copied token immediately
- [ ] Added to GitHub Secrets as `TF_API_TOKEN`
- [ ] Verified token in GitHub Actions workflow

---

## 🔗 Full Documentation

For detailed instructions, see: [docs/TERRAFORM-TOKEN-GUIDE.md](./TERRAFORM-TOKEN-GUIDE.md)

---

**Need Help?** Check the full guide: `docs/TERRAFORM-TOKEN-GUIDE.md`

