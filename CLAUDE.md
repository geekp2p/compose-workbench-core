# Repo: multi-compose-lab

## Goal
Refactor + standardize scripts and compose files while keeping behavior unchanged.

## Structure
- Root scripts: up.ps1/down.ps1/clean.ps1/service.ps1 and cmd wrappers
- Projects live in ./projects/*
  - go-hello, node-hello, py-hello, solo-node
- Templates: 5 base templates (see TEMPLATES.md)
  - go-template, node-template, python-template, web-stack, microservice

## How to Run

### Basic Commands
- Start: `.\up.ps1 <project> -Build`
- Stop:  `.\down.ps1 <project>`
- Clean: `.\clean.ps1 -Project <project> [-Deep] [-Force]`

### Service Management (Multi-Service Projects)
- List services: `.\service.ps1 <project> -List`
- Start service: `.\service.ps1 <project> -Service <name> -Start`
- Stop service: `.\service.ps1 <project> -Service <name> -Stop`
- Restart service: `.\service.ps1 <project> -Service <name> -Restart`
- View logs: `.\service.ps1 <project> -Service <name> -Logs`
- Start multiple: `.\service.ps1 <project> -Service svc1,svc2 -Start`

### Help System
- Interactive help: `.\help.ps1`
- Quick status: `.\help.ps1 status`
- Templates list: `.\help.ps1 templates`

---

## Development Rules

### General Rules
1. **Do not change exposed ports unless requested**
   - Each project must use unique ports
   - Default port allocation:
     - `8001` - Python projects
     - `8002` - Go projects
     - `8003` - Node.js projects
     - `8004-8006` - Web Stack services
     - `8007-8008` - Microservices
     - `8010+` - Custom projects

2. **Prefer backward-compatible refactors**
   - Existing scripts and compose files should continue working
   - Add new features without breaking old ones
   - Use environment variables for optional features

3. **Always show diffs; do not auto-accept large changes**
   - Review changes before committing
   - Use `git diff` to verify modifications
   - Test changes locally before pushing

4. **PowerShell compatibility**
   - Keep scripts compatible with Windows PowerShell 5.1 AND PowerShell 7+
   - Test on both versions if possible
   - Avoid cmdlets/features only in PS 7

### Port Management
- **NEVER change ports without explicit user request**
- Use environment variables for flexibility:
  ```yaml
  services:
    web:
      ports:
        - "${HOST_PORT:-8001}:5000"  # Default 8001, override with env
  ```
- Document port usage in README.md and TEMPLATES.md
- Check for port conflicts before assigning new ones

### Multi-Service Projects
When working with projects that have multiple services (e.g., solo-node, web-stack):

1. **Always use `depends_on` with health checks:**
   ```yaml
   services:
     web:
       depends_on:
         db:
           condition: service_healthy  # Wait for db to be ready
   ```

2. **Every service MUST have a health check:**
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
     interval: 30s
     timeout: 10s
     retries: 3
     start_period: 40s  # Grace period for startup
   ```

3. **Use YAML anchors to reduce duplication:**
   ```yaml
   x-common-healthcheck: &common-healthcheck
     interval: 30s
     timeout: 10s
     retries: 3

   services:
     service1:
       healthcheck:
         <<: *common-healthcheck
         test: ["CMD", "curl", "localhost"]
   ```

4. **Service naming convention:**
   - Use descriptive names: `web`, `api`, `db`, `cache`
   - Avoid generic names like `service1`, `app1`
   - Prefix with project name for uniqueness: `myapp-web`, `myapp-db`

### compose.yml Guidelines

1. **Required fields in every compose.yml:**
   ```yaml
   name: project-name  # Must match directory name

   services:
     web:
       build: .  # or image: ...
       ports:
         - "${HOST_PORT:-8001}:5000"
       environment:
         - PORT=5000
       restart: unless-stopped
       healthcheck:
         test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
         interval: 30s
         timeout: 10s
         retries: 3
   ```

2. **Always use named volumes for persistent data:**
   ```yaml
   services:
     db:
       volumes:
         - db-data:/var/lib/postgresql/data  # Named volume

   volumes:
     db-data:  # Declare at bottom
   ```

3. **Use environment variables for configuration:**
   ```yaml
   services:
     web:
       environment:
         - PORT=${PORT:-8080}
         - DATABASE_URL=${DATABASE_URL}
         - NODE_ENV=${NODE_ENV:-production}
   ```

4. **Add restart policies:**
   ```yaml
   services:
     web:
       restart: unless-stopped  # Preferred
       # OR restart: always
       # OR restart: on-failure
   ```

### Dockerfile Guidelines

1. **Use multi-stage builds for compiled languages:**
   ```dockerfile
   # Go example
   FROM golang:1.21-alpine AS builder
   WORKDIR /app
   COPY . .
   RUN go build -o app .

   FROM alpine:latest
   COPY --from=builder /app/app .
   CMD ["./app"]
   ```

2. **Use slim/alpine images:**
   ```dockerfile
   # Good
   FROM python:3.11-slim
   FROM node:18-alpine
   FROM golang:1.21-alpine

   # Avoid
   FROM python:3.11  # Too large
   FROM node:18      # Too large
   ```

3. **Layer caching for dependencies:**
   ```dockerfile
   # Install dependencies first (cached layer)
   COPY package*.json ./
   RUN npm ci --only=production

   # Then copy application code
   COPY . .
   ```

4. **Include health check tools:**
   ```dockerfile
   # Add curl/wget for health checks
   FROM alpine:latest
   RUN apk --no-cache add ca-certificates curl

   # Or use specific tools
   RUN apk add --no-cache postgresql-client  # For pg_isready
   ```

5. **Use non-root users:**
   ```dockerfile
   # Node.js
   USER node

   # Python
   USER nobody

   # Custom user
   RUN adduser -D appuser
   USER appuser
   ```

### Templates Guidelines

When creating new templates or modifying existing ones:

1. **Follow naming convention:**
   - Simple services: `<language>-template` (e.g., `go-template`)
   - Multi-service: `<purpose>-template` (e.g., `web-stack`, `microservice`)

2. **Include these files:**
   ```
   projects/template-name/
   ├── compose.yml       # Docker Compose config
   ├── Dockerfile        # Container build instructions
   ├── README.md         # Template documentation
   ├── .env.example      # Environment variables template
   └── <source-files>    # Application code
   ```

3. **Document in TEMPLATES.md:**
   - Add to template overview table
   - Create detailed section with:
     - Use case
     - Directory structure
     - Dockerfile highlights
     - Example endpoints
     - Usage instructions

4. **Update README.md:**
   - Add to "Available Templates" table
   - Add example scenario if applicable

### Scripts Enhancement

When modifying PowerShell scripts (up.ps1, down.ps1, clean.ps1, service.ps1):

1. **Parameter validation:**
   ```powershell
   param(
       [Parameter(Mandatory=$true)]
       [string]$Project,

       [Parameter(Mandatory=$false)]
       [switch]$Build
   )

   # Validate project exists
   if (-not (Test-Path "projects/$Project")) {
       Write-Error "Project '$Project' not found"
       exit 1
   }
   ```

2. **Error handling:**
   ```powershell
   try {
       docker compose -f "projects/$Project/compose.yml" up -d
   }
   catch {
       Write-Error "Failed to start project: $_"
       exit 1
   }
   ```

3. **Informative output:**
   ```powershell
   Write-Host "Starting project: $Project" -ForegroundColor Green
   Write-Host "Port: $Port" -ForegroundColor Cyan
   Write-Host "URL: http://localhost:$Port" -ForegroundColor Yellow
   ```

4. **Common module usage:**
   ```powershell
   # Import shared functions
   Import-Module "$PSScriptRoot/common.psm1"

   # Use common functions
   $projectPath = Get-ProjectPath $Project
   Test-DockerRunning
   ```

---

## Testing Checklist

Before committing changes, verify:

- [ ] **Scripts work on both PowerShell 5.1 and 7+**
  ```powershell
  # Test on PS 5.1
  powershell -Version 5.1 -File up.ps1 test-project -Build

  # Test on PS 7
  pwsh -File up.ps1 test-project -Build
  ```

- [ ] **All projects start successfully**
  ```powershell
  .\up.ps1 go-hello -Build
  .\up.ps1 node-hello -Build
  .\up.ps1 py-hello -Build
  .\up.ps1 solo-node -Build
  ```

- [ ] **Multi-service management works**
  ```powershell
  .\service.ps1 solo-node -List
  .\service.ps1 solo-node -Service bitcoin-main -Start
  .\service.ps1 solo-node -Service bitcoin-main -Logs
  ```

- [ ] **Health checks pass**
  ```powershell
  # Wait 30s after startup
  Start-Sleep 30
  docker ps --filter "health=healthy"
  ```

- [ ] **Cleanup works correctly**
  ```powershell
  .\clean.ps1 -Project test-project
  .\clean.ps1 -Project test-project -Deep
  .\clean.ps1 -All -Force
  ```

- [ ] **Port conflicts resolved**
  ```powershell
  # Check no port conflicts
  netstat -ano | findstr ":8001"
  netstat -ano | findstr ":8002"
  ```

- [ ] **Documentation updated**
  - [ ] README.md reflects changes
  - [ ] TEMPLATES.md includes new templates
  - [ ] CLAUDE.md has new guidelines
  - [ ] help.ps1 shows new features

- [ ] **Git workflow**
  ```powershell
  git status
  git diff
  git add .
  git commit -m "Clear, descriptive message"
  git push
  ```

---

## Documentation Requirements

When adding new features, update:

1. **README.md**
   - Quick Start section (if startup process changes)
   - Available Templates table (if new template added)
   - การรันโปรเจค section (if new commands added)
   - สรุปคำสั่งทั้งหมด tables (if new commands added)
   - ตัวอย่างการใช้งานจริง scenarios (if new use case)

2. **TEMPLATES.md**
   - Template Overview table (if new template)
   - Detailed section for new template
   - Template Comparison table (update features)
   - Best Practices (if new pattern discovered)

3. **help.ps1**
   - Add new commands to help menu
   - Update examples
   - Add new categories if needed

4. **CLAUDE.md (this file)**
   - Update rules if new conventions established
   - Add to testing checklist if new validation needed
   - Document common patterns

5. **Project-specific README.md**
   - Each template should have its own README.md
   - Include: description, features, env vars, usage

---

## Common Patterns

### Adding New Parameter to Script

```powershell
# Before
param(
    [Parameter(Mandatory=$true)]
    [string]$Project
)

# After
param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [Parameter(Mandatory=$false)]
    [switch]$NewFeature  # Add new parameter
)

# Use parameter
if ($NewFeature) {
    Write-Host "New feature enabled!" -ForegroundColor Green
    # Implementation
}
```

### Adding New Template

1. **Create project structure:**
   ```powershell
   mkdir projects/my-template
   cd projects/my-template
   ```

2. **Create compose.yml:**
   ```yaml
   name: my-template
   services:
     web:
       build: .
       ports:
         - "${HOST_PORT:-8010}:8080"
       healthcheck:
         test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
   ```

3. **Create Dockerfile:**
   ```dockerfile
   FROM <base-image>
   WORKDIR /app
   COPY . .
   RUN <build-command>
   EXPOSE 8080
   CMD [<start-command>]
   ```

4. **Test:**
   ```powershell
   .\up.ps1 my-template -Build
   curl http://localhost:8010/health
   .\down.ps1 my-template
   ```

5. **Document:**
   - Add to TEMPLATES.md
   - Add to README.md Available Templates table
   - Create projects/my-template/README.md

### Adding New Command to service.ps1

```powershell
# Add parameter
param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [Parameter(Mandatory=$false)]
    [string]$Service,

    [switch]$Start,
    [switch]$Stop,
    [switch]$Restart,
    [switch]$Logs,
    [switch]$List,
    [switch]$NewCommand  # Add new switch
)

# Implement
if ($NewCommand) {
    Write-Host "Executing new command for $Service" -ForegroundColor Green
    docker compose -f "projects/$Project/compose.yml" <new-command> $Service
    exit 0
}
```

---

## Git Workflow

### Before Making Changes
```powershell
# Create feature branch
git checkout -b feature/my-feature

# Ensure clean working directory
git status
```

### During Development
```powershell
# Check changes frequently
git diff

# Stage specific files
git add README.md TEMPLATES.md

# Commit with clear message
git commit -m "Add web-stack template with 3 services"
```

### Before Pushing
```powershell
# Run tests
.\up.ps1 test-project -Build
.\service.ps1 test-project -List
.\clean.ps1 -Project test-project

# Review all changes
git diff main

# Push to feature branch
git push origin feature/my-feature
```

### Commit Message Format
```
<type>: <short description>

<detailed description if needed>

Examples:
- "feat: Add microservice template with Redis caching"
- "fix: Resolve port conflict in web-stack template"
- "docs: Update README with multi-service examples"
- "refactor: Simplify service.ps1 parameter handling"
- "test: Add health check validation to all templates"
```

---

## Troubleshooting Common Issues

### Issue: Port Already in Use
```powershell
# Check what's using the port
netstat -ano | findstr :8001

# Solution: Use different port
$env:HOST_PORT=9001
.\up.ps1 my-project -Build
```

### Issue: Container Not Healthy
```powershell
# Check logs
.\service.ps1 my-project -Service web -Logs

# Common fixes:
# 1. Increase healthcheck start_period
# 2. Fix healthcheck command
# 3. Ensure service actually starts
```

### Issue: PowerShell Script Fails
```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Test on both versions
powershell -Version 5.1 -File script.ps1
pwsh -File script.ps1
```

### Issue: Docker Compose File Invalid
```powershell
# Validate syntax
docker compose -f projects/my-project/compose.yml config

# Check for common errors:
# 1. Incorrect indentation (use 2 spaces)
# 2. Missing quotes around version numbers
# 3. Invalid YAML anchors
```

---

## Performance Optimization

### Build Cache
```dockerfile
# Order instructions from least to most frequently changing
FROM node:18-alpine
WORKDIR /app

# 1. Dependencies (changes rarely)
COPY package*.json ./
RUN npm ci --only=production

# 2. Application code (changes often)
COPY . .
```

### Parallel Builds
```powershell
# Build multiple projects simultaneously
Start-Job -ScriptBlock { .\up.ps1 go-hello -Build }
Start-Job -ScriptBlock { .\up.ps1 node-hello -Build }
Start-Job -ScriptBlock { .\up.ps1 py-hello -Build }

# Wait for all
Get-Job | Wait-Job
```

### Image Size Reduction
```dockerfile
# Use alpine variants
FROM node:18-alpine  # ~180MB vs node:18 ~900MB

# Multi-stage builds
FROM golang:1.21-alpine AS builder
# ... build steps ...
FROM alpine:latest  # Final image ~20MB

# Clean up in same layer
RUN apk add --no-cache python3 && \
    pip install requirements.txt && \
    apk del .build-deps
```

---

## Resources

- **[README.md](README.md)** - User documentation and quick start
- **[TEMPLATES.md](TEMPLATES.md)** - Template details and best practices
- **[RECOMMENDATIONS.md](RECOMMENDATIONS.md)** - Additional best practices
- **[Docker Compose Docs](https://docs.docker.com/compose/)** - Official documentation
- **[PowerShell Docs](https://learn.microsoft.com/en-us/powershell/)** - PowerShell reference

---

## Questions?

- Check existing issues in repository
- Review help.ps1: `.\help.ps1`
- Read documentation: README.md, TEMPLATES.md
- Test changes locally before asking
