# How to Generate Terraform Cloud API Token

## Step-by-Step Guide

### Method 1: Via Terraform Cloud Web UI (Recommended)

#### 1. Log in to Terraform Cloud
1. Go to [https://app.terraform.io](https://app.terraform.io)
2. Sign in with your account (or create a new account if you don't have one)

#### 2. Navigate to User Settings
1. Click on your **profile icon** in the top right corner
2. Select **"User Settings"** from the dropdown menu

#### 3. Go to Tokens Section
1. In the left sidebar, click on **"Tokens"**
2. You'll see a list of your existing tokens (if any)

#### 4. Create a New Token
1. Click the **"Create an API token"** button
2. Enter a **description** for the token (e.g., "GitHub Actions CI/CD", "Local Development", etc.)
3. Optionally set an **expiration date**:
   - **30 days** (recommended for testing)
   - **90 days**
   - **Custom date**
   - **No expiration** (not recommended for security reasons)
4. Click **"Generate token"**

#### 5. Copy the Token
⚠️ **IMPORTANT**: The token will only be displayed **ONCE**!

1. **Copy the token immediately** and save it securely
2. Store it in a password manager or secure location
3. You'll use this token for the `TF_API_TOKEN` GitHub Secret

#### 6. Verify Token Created
- The token should now appear in your tokens list
- Note the description and creation date for reference

---

### Method 2: Via Terraform CLI

If you prefer using the command line:

```bash
# Login to Terraform Cloud
terraform login

# This will:
# 1. Open your browser to generate a token
# 2. Prompt you to paste the token in the terminal
# 3. Store it in ~/.terraform.d/credentials.tfrc.json

# To view the stored token (on Windows):
type %APPDATA%\terraform.d\credentials.tfrc.json

# On Linux/Mac:
cat ~/.terraform.d/credentials.tfrc.json
```

The token will be in this format:
```json
{
  "credentials": {
    "app.terraform.io": {
      "token": "your-token-here.atlasv1.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    }
  }
}
```

---

### Method 3: Via API (Advanced)

For automation or programmatic access:

```bash
# Create a token via API (requires existing token or credentials)
curl \
  --header "Authorization: Bearer $EXISTING_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data '{
    "data": {
      "type": "authentication-tokens",
      "attributes": {
        "description": "GitHub Actions Token"
      }
    }
  }' \
  https://app.terraform.io/api/v2/users/$(whoami)/authentication-tokens
```

---

## Adding Token to GitHub Secrets

Once you have your Terraform Cloud API token:

### 1. Go to Your GitHub Repository
1. Navigate to your repository: `https://github.com/YOUR_USERNAME/agentic-ai`
2. Click on **"Settings"** tab

### 2. Navigate to Secrets
1. In the left sidebar, expand **"Secrets and variables"**
2. Click on **"Actions"**

### 3. Add New Secret
1. Click **"New repository secret"** button
2. Enter the following:
   - **Name**: `TF_API_TOKEN`
   - **Secret**: Paste your Terraform Cloud API token
3. Click **"Add secret"**

### 4. Verify Secret Added
- You should see `TF_API_TOKEN` in the list of secrets
- The value will be hidden (shown as `***`)

---

## Token Format

A valid Terraform Cloud API token looks like this:

```
your-token-name.atlasv1.aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890
```

Key characteristics:
- Starts with a description (e.g., `your-token-name`)
- Contains `.atlasv1.`
- Followed by a long alphanumeric string
- Total length: ~90+ characters

---

## Token Types in Terraform Cloud

### User Tokens (What You Need)
- **Scope**: All workspaces you have access to
- **Use Case**: GitHub Actions, local development
- **Permissions**: Based on your user role
- ✅ **This is what you need for `TF_API_TOKEN`**

### Team Tokens
- **Scope**: Specific to a team within an organization
- **Use Case**: Team-based access control
- **Permissions**: Based on team permissions

### Organization Tokens
- **Scope**: All workspaces in an organization
- **Use Case**: Service accounts, automation
- **Permissions**: Full organization access

---

## Security Best Practices

### ✅ Do's
- ✅ Set token expiration dates (30-90 days)
- ✅ Use descriptive names (e.g., "GitHub Actions - Prod")
- ✅ Store tokens securely (password manager, GitHub Secrets)
- ✅ Rotate tokens regularly
- ✅ Create separate tokens for different environments
- ✅ Revoke unused tokens immediately

### ❌ Don'ts
- ❌ Never commit tokens to Git
- ❌ Don't share tokens between projects/people
- ❌ Don't use tokens with no expiration for production
- ❌ Don't store tokens in plain text files
- ❌ Don't reuse the same token across multiple services

---

## Troubleshooting

### Issue: "Invalid Token" Error

**Symptom**: GitHub Actions fails with "Invalid credentials" or "Unauthorized"

**Solutions**:
1. Verify the token is copied correctly (no extra spaces)
2. Check if the token has expired
3. Ensure the token has the correct permissions
4. Regenerate a new token if needed

### Issue: Token Not Working in Terraform CLI

**Symptom**: `terraform init` fails to authenticate

**Solutions**:
1. Run `terraform logout` then `terraform login` again
2. Check `~/.terraform.d/credentials.tfrc.json` exists and has the token
3. Verify the token format is correct

### Issue: "Token Not Found" in GitHub Actions

**Symptom**: Workflow can't access `TF_API_TOKEN`

**Solutions**:
1. Verify the secret name is exactly `TF_API_TOKEN` (case-sensitive)
2. Check the secret is added to the repository (not organization level)
3. Ensure the workflow references it correctly: `${{ secrets.TF_API_TOKEN }}`

---

## Testing Your Token

### Test 1: Verify Token via API

```bash
# Replace YOUR_TOKEN with your actual token
curl \
  --header "Authorization: Bearer YOUR_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/account/details
```

Expected response:
```json
{
  "data": {
    "id": "user-xxxxx",
    "type": "users",
    "attributes": {
      "username": "your-username",
      "email": "your-email@example.com"
    }
  }
}
```

### Test 2: Test in Terraform CLI

```bash
cd infrastructure/terraform

# This should work without prompting for credentials
terraform init
```

### Test 3: Test in GitHub Actions

Create a simple test workflow:

```yaml
name: Test Terraform Token
on: workflow_dispatch

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v3
        with:
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
      
      - run: terraform version
```

---

## Token Lifecycle Management

### Creating Tokens for Different Purposes

```
GitHub Actions (Production):
- Name: "GitHub Actions - Prod"
- Expiration: 90 days
- Scope: Production workspaces

GitHub Actions (Development):
- Name: "GitHub Actions - Dev"
- Expiration: 30 days
- Scope: Development workspaces

Local Development:
- Name: "Local Dev - Your Name"
- Expiration: 30 days
- Scope: All workspaces
```

### Rotating Tokens

**When to Rotate**:
- Before expiration (set reminders)
- After a team member leaves
- If token may have been compromised
- Every 90 days (security best practice)

**How to Rotate**:
1. Create a new token with the same permissions
2. Update GitHub Secrets with new token
3. Test the new token
4. Revoke the old token
5. Document the rotation in your team log

---

## Quick Reference

### Token Generation URL
```
https://app.terraform.io/app/settings/tokens
```

### Direct Links
- **Create Token**: https://app.terraform.io/app/settings/tokens
- **User Settings**: https://app.terraform.io/app/settings/profile
- **Organizations**: https://app.terraform.io/app/organizations

### GitHub Secrets URL
```
https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions
```

---

## Next Steps After Generating Token

1. ✅ **Copy the token** immediately
2. ✅ **Add to GitHub Secrets** as `TF_API_TOKEN`
3. ✅ **Update Terraform Cloud workspace**
   - Add `AWS_ACCESS_KEY_ID`
   - Add `AWS_SECRET_ACCESS_KEY`
4. ✅ **Run the setup script**:
   ```powershell
   ./scripts/setup-github-actions.ps1
   ```
5. ✅ **Test the deployment**:
   - Go to Actions → "Deploy Full Stack"
   - Run workflow

---

## Support Resources

- **Terraform Cloud Docs**: https://developer.hashicorp.com/terraform/cloud-docs/users-teams-organizations/api-tokens
- **GitHub Secrets Docs**: https://docs.github.com/en/actions/security-guides/encrypted-secrets
- **Terraform CLI Login**: https://developer.hashicorp.com/terraform/cli/commands/login

---

**Summary**: Generate token at https://app.terraform.io/app/settings/tokens → Copy it → Add to GitHub Secrets as `TF_API_TOKEN` ✅

