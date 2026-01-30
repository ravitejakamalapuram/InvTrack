# NPM Registry Troubleshooting Guide

## 🎯 Problem

Your company might have:
- Custom npm registry (e.g., Artifactory, Nexus)
- Firewall blocking public npm registry
- Proxy requirements
- SSL certificate issues

This can cause `npm install` to fail in GitHub Actions workflows.

---

## ✅ Solutions (Multiple Options)

---

### **Solution 1: Environment-Scoped Registry + Cache (Already Implemented)**

**What we added:**
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '18'
    cache: 'npm'  # ✅ Caches npm packages
    cache-dependency-path: '**/package.json'

- name: Install dependencies
  env:
    # Environment-scoped config (doesn't affect system)
    NPM_CONFIG_REGISTRY: https://registry.npmjs.org/
    NPM_CONFIG_PREFER_OFFLINE: true
    NPM_CONFIG_NO_AUDIT: true
    NPM_CONFIG_NO_FUND: true
  run: |
    npm install firebase-admin
```

**How it helps:**
- ✅ **Environment-scoped**: Only affects this workflow step, not system npm config
- ✅ **Explicit registry**: Uses public npm registry (bypasses system config)
- ✅ **Cache preference**: Uses cached packages when available
- ✅ **No side effects**: Doesn't modify ~/.npmrc or system settings

**When it works:**
- ✅ After first successful run, packages are cached
- ✅ Even if npm registry is down, cache is used
- ✅ Isolated from company npm registry settings
- ✅ Won't affect other processes on the runner

---

### **Solution 2: Configure Custom npm Registry**

If your company uses a custom registry (e.g., Artifactory):

#### **Option A: Via .npmrc file**

Create `.npmrc` in your repository root:

```bash
# .npmrc
registry=https://your-company-registry.com/npm/
//your-company-registry.com/npm/:_authToken=${NPM_TOKEN}
```

Then add GitHub secret:
```bash
# GitHub → Settings → Secrets → Actions
Name: NPM_TOKEN
Value: <your npm auth token>
```

Update workflow:
```yaml
- name: Setup npm registry
  run: |
    echo "//your-company-registry.com/npm/:_authToken=${{ secrets.NPM_TOKEN }}" > ~/.npmrc
    echo "registry=https://your-company-registry.com/npm/" >> ~/.npmrc

- name: Install dependencies
  run: npm install firebase-admin
```

#### **Option B: Via environment variable**

```yaml
- name: Install dependencies
  env:
    NPM_CONFIG_REGISTRY: https://your-company-registry.com/npm/
    NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
  run: npm install firebase-admin
```

---

### **Solution 3: Pre-bundle Dependencies (Most Reliable)**

**Idea:** Bundle the npm packages in your repository so no network is needed.

#### **Step 1: Create a package.json**

```bash
# In your repository root:
cat > package.json << 'EOF'
{
  "name": "invtrack-ci",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "googleapis": "^131.0.0"
  }
}
EOF
```

#### **Step 2: Install and commit node_modules**

```bash
# Install packages locally
npm install

# Commit node_modules (normally not recommended, but useful for CI)
git add package.json package-lock.json node_modules/
git commit -m "Add npm dependencies for CI"
git push
```

#### **Step 3: Update workflows to use local packages**

```yaml
- name: Install dependencies
  run: |
    # Packages are already in node_modules, just verify
    if [ -d "node_modules" ]; then
      echo "✅ Using bundled dependencies"
      npm list firebase-admin googleapis
    else
      echo "⚠️ Bundled dependencies not found, installing..."
      npm install
    fi
```

**Pros:**
- ✅ No network dependency
- ✅ Works offline
- ✅ Guaranteed to work

**Cons:**
- ⚠️ Increases repository size (~50-100 MB)
- ⚠️ Need to update manually when upgrading packages

---

### **Solution 4: Use Docker Container with Pre-installed Packages**

If you have Docker on your self-hosted runner:

#### **Create Dockerfile:**

```dockerfile
# Dockerfile
FROM node:18-alpine

# Install dependencies
RUN npm install -g firebase-admin googleapis

# Set working directory
WORKDIR /workspace

CMD ["/bin/sh"]
```

#### **Build and use in workflow:**

```yaml
jobs:
  check-approval:
    runs-on: self-hosted
    container:
      image: invtrack-ci:latest  # Your pre-built image
    
    steps:
      - name: Check dependencies
        run: |
          node -e "console.log(require('firebase-admin').SDK_VERSION)"
```

---

### **Solution 5: Fallback to System-Installed Packages**

If you already have Node.js and packages installed on your runner:

#### **Install packages globally on your runner (one-time):**

```bash
# On your self-hosted runner machine:
npm install -g firebase-admin googleapis
```

#### **Update workflow to use global packages:**

```yaml
- name: Install dependencies
  run: |
    # Try local install first
    npm install firebase-admin googleapis --prefer-offline || {
      echo "⚠️ Local install failed, checking global packages..."
      
      # Check if globally installed
      if npm list -g firebase-admin googleapis; then
        echo "✅ Using globally installed packages"
        export NODE_PATH=$(npm root -g)
      else
        echo "❌ Packages not found globally either"
        exit 1
      fi
    }
```

---

## 🔧 **Recommended Approach for Your Setup**

Based on your situation (self-hosted runner + potential company registry issues):

### **Best Solution: Hybrid Approach**

1. **Use npm cache** (already implemented) ✅
2. **Pre-install packages globally on runner** (one-time setup)
3. **Fallback to global if local fails**

#### **One-time setup on your runner:**

```bash
# SSH into your self-hosted runner
ssh your-runner-machine

# Install packages globally
npm install -g firebase-admin@12.0.0 googleapis@131.0.0

# Verify installation
npm list -g firebase-admin googleapis
```

#### **Update workflow with fallback:**

Let me create an improved version:


