# Initialize Git Repository from GitHub

This guide helps you set up a local Git repository and connect it to an existing GitHub repository.

## When to Use This Guide

Use this guide when:
- You have a folder that is NOT yet a Git repository
- You want to pull content from an existing GitHub repository
- You see error: `fatal: not a git repository (or any of the parent directories): .git`

## Prerequisites

1. **Git installed** - Download from [git-scm.com](https://git-scm.com/downloads)
2. **GitHub account** - You need access to the target repository
3. **GitHub Personal Access Token (PAT)** - For HTTPS authentication (recommended)

## Quick Start

### For compose-workbench-core Repository

If you're setting up the `compose-workbench-core` repository, run:

```powershell
# Navigate to your folder
cd C:\multiprojlab\compose-workbench-core

# Run the initialization script
.\init-from-github.ps1 -RepoUrl "https://github.com/geekp2p/compose-workbench-core"
```

### For Other Repositories

```powershell
# Navigate to your project folder
cd C:\path\to\your\folder

# Copy the init-from-github.ps1 script to your folder
# Then run:
.\init-from-github.ps1 -RepoUrl "https://github.com/username/repo-name"
```

## Step-by-Step Manual Process

If you prefer to do it manually or the script doesn't work:

### Step 1: Initialize Git Repository

```powershell
# Check if folder is already a git repo
git status

# If you see "fatal: not a git repository", initialize it:
git init
```

### Step 2: Configure Git User

```powershell
# Set your name
git config user.name "Your Name"

# Set your email
git config user.email "your.email@example.com"
```

### Step 3: Add Remote Repository

```powershell
# Add the GitHub repository as remote
git remote add origin https://github.com/username/repo-name.git

# Verify remote was added
git remote -v
```

### Step 4: Configure Credential Helper (Windows)

```powershell
# Store credentials (for HTTPS)
git config --global credential.helper wincred
```

### Step 5: Fetch and Pull from GitHub

```powershell
# Fetch all branches from remote
git fetch origin

# List available branches
git branch -r

# Checkout the main branch (or your desired branch)
git checkout -b main origin/main
```

### Step 6: Verify Setup

```powershell
# Check current branch
git branch

# Check status
git status

# View files
git ls-files
```

## Authentication

### HTTPS Authentication (Recommended)

When you first push/pull, Git will ask for:
- **Username**: Your GitHub username
- **Password**: Your GitHub Personal Access Token (PAT)

#### Creating a Personal Access Token

1. Go to GitHub: [Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Give it a descriptive name (e.g., "compose-workbench-core")
4. Select scopes:
   - ✅ `repo` (full control of private repositories)
5. Click "Generate token"
6. **Copy the token** - you won't see it again!
7. Use this token as your password when Git asks

### SSH Authentication (Advanced)

If you prefer SSH:

```powershell
# Generate SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Start SSH agent
Start-Service ssh-agent

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub | clip

# Add to GitHub: Settings → SSH and GPG keys → New SSH key
```

Then use SSH URL:
```powershell
.\init-from-github.ps1 -RepoUrl "git@github.com:username/repo-name.git" -Method ssh
```

## Common Issues & Solutions

### Issue 1: "fatal: not a git repository"

**Solution**: You haven't initialized Git yet. Run:
```powershell
git init
```

### Issue 2: "Authentication failed"

**Solution**:
- Make sure you're using a Personal Access Token, NOT your GitHub password
- Check token has correct permissions (`repo` scope)
- Try clearing credentials:
  ```powershell
  git credential-manager erase https://github.com
  ```

### Issue 3: "Branch 'main' does not exist"

**Solution**: The default branch might be different. Check available branches:
```powershell
git ls-remote --heads origin
```

Then specify the correct branch:
```powershell
.\init-from-github.ps1 -RepoUrl "..." -Branch "master"
```

### Issue 4: "Remote 'origin' already exists"

**Solution**: Remove existing remote and add again:
```powershell
git remote remove origin
git remote add origin https://github.com/username/repo-name.git
```

### Issue 5: Script execution disabled

**Solution**: Enable script execution (run as Administrator):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Script Parameters

### init-from-github.ps1

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `-RepoUrl` | GitHub repository URL | *Required* | `https://github.com/user/repo` |
| `-Branch` | Branch to checkout | `main` | `master`, `develop` |
| `-Method` | Auth method (https/ssh) | `https` | `ssh` |

### Examples

**Basic usage (HTTPS):**
```powershell
.\init-from-github.ps1 -RepoUrl "https://github.com/geekp2p/compose-workbench-core"
```

**Specify branch:**
```powershell
.\init-from-github.ps1 -RepoUrl "https://github.com/user/repo" -Branch "develop"
```

**Use SSH:**
```powershell
.\init-from-github.ps1 -RepoUrl "git@github.com:user/repo.git" -Method ssh
```

## Next Steps

After successful initialization:

1. **Verify files are present:**
   ```powershell
   dir
   git status
   ```

2. **Make changes and commit:**
   ```powershell
   # Make your changes
   git add .
   git commit -m "Your commit message"
   ```

3. **Push changes:**
   ```powershell
   git push -u origin main
   ```

4. **Use other Git operations:**
   ```powershell
   # Pull latest changes
   git pull origin main

   # Create new branch
   git checkout -b feature/my-feature

   # View commit history
   git log --oneline
   ```

## Helper Scripts

After initialization, you can use these scripts:

- **setup-repo.ps1** - Change remote repository URL
- **git-helper.ps1** - Simplified Git operations (if available)

## Folder Structure

After initialization, your folder should look like:

```
compose-workbench-core/
├── .git/                    # Git repository data
├── LICENSE                  # License file
├── README.md               # Repository documentation
└── [other project files]   # Project content from GitHub
```

## Troubleshooting Checklist

Before asking for help, verify:

- [ ] Git is installed: `git --version`
- [ ] You're in the correct folder: `pwd` or `cd`
- [ ] Folder is not already a Git repo: `git status` should fail
- [ ] GitHub URL is correct and accessible
- [ ] You have access to the repository (check on GitHub website)
- [ ] Internet connection is working
- [ ] Antivirus/firewall not blocking Git

## Additional Resources

- [Git Official Documentation](https://git-scm.com/doc)
- [GitHub Authentication Guide](https://docs.github.com/en/authentication)
- [Git Credential Manager](https://github.com/GitCredentialManager/git-credential-manager)

## Summary Commands (Quick Reference)

```powershell
# Initialize and pull from GitHub (automated)
.\init-from-github.ps1 -RepoUrl "https://github.com/user/repo"

# Manual initialization
git init
git config user.name "Your Name"
git config user.email "your.email@example.com"
git remote add origin https://github.com/user/repo.git
git fetch origin
git checkout -b main origin/main

# Verify setup
git status
git branch
git remote -v

# First push
git add .
git commit -m "Initial commit"
git push -u origin main
```

---

**Need help?** Check the [GitHub Issues](https://github.com/geekp2p/compose-workbench-core/issues) or contact the repository maintainer.
