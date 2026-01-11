# ============================================================
# run.ps1
# Create new Docker compose projects from templates
# ============================================================

using module .\common.psm1

param(
  [Parameter(Mandatory=$true, Position=0)]
  [ValidateSet("new", "list", "remove", "delete")]
  [string]$Command,

  [Parameter(Position=1)]
  [string]$ProjectName,

  [Parameter()]
  [ValidateSet("go", "node", "python", "py", "web-stack", "microservice")]
  [string]$Lang,

  [Parameter()]
  [int]$Port = 0,

  [Parameter()]
  [switch]$Force
)

$root = Get-ScriptRoot
$projectsDir = Join-Path $root "projects"

function Get-NextAvailablePort {
    <#
    .SYNOPSIS
    Finds the next available port by checking existing projects.
    #>
    $usedPorts = @()

    Get-ChildItem $projectsDir -Directory | ForEach-Object {
        $composePath = Join-Path $_.FullName "compose.yml"
        if (Test-Path $composePath) {
            $content = Get-Content $composePath -Raw
            # Extract HOST_PORT values (e.g., ${HOST_PORT:-8001})
            if ($content -match '\$\{HOST_PORT:-(\d+)\}') {
                $usedPorts += [int]$Matches[1]
            }
        }
    }

    # Start from 8001 and find next available
    $port = 8001
    while ($usedPorts -contains $port) {
        $port++
    }

    return $port
}

function Get-LanguageDefaults {
    param([string]$Language)

    switch ($Language) {
        "go" {
            return @{
                Port = 8080
                Files = @{
                    "Dockerfile" = @"
FROM golang:1.22-alpine AS builder
WORKDIR /src

COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server .

FROM alpine:3.20
WORKDIR /app
COPY --from=builder /out/server /app/server

EXPOSE 8080
ENV PORT=8080
CMD ["/app/server"]
"@
                    "go.mod" = "module {{PROJECT_NAME}}`n`ngo 1.22`n"
                    "main.go" = @"
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

type Resp struct {
	Project  string ``json:"project"``
	Language string ``json:"language"``
	TimeUTC  string ``json:"time_utc"``
	Note     string ``json:"note"``
}

func handler(w http.ResponseWriter, r *http.Request) {
	resp := Resp{
		Project:  "{{PROJECT_NAME}}",
		Language: "go",
		TimeUTC:  time.Now().UTC().Format(time.RFC3339Nano),
		Note:     "If you can see this JSON, Docker build + port mapping works.",
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", handler)

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("{{PROJECT_NAME}} listening on %s", srv.Addr)
	log.Fatal(srv.ListenAndServe())
}
"@
                }
            }
        }
        "node" {
            return @{
                Port = 3000
                Files = @{
                    "Dockerfile" = @"
FROM node:20-alpine

WORKDIR /app
COPY package.json /app/
RUN npm install --omit=dev

COPY server.js /app/server.js

EXPOSE 3000
ENV PORT=3000
CMD ["npm", "start"]
"@
                    "package.json" = @"
{
  "name": "{{PROJECT_NAME}}",
  "version": "1.0.0",
  "private": true,
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
"@
                    "server.js" = @"
const express = require("express");
const os = require("os");

const app = express();
const port = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.json({
    project: "{{PROJECT_NAME}}",
    language: "node",
    hostname: os.hostname(),
    note: "If you can see this JSON, Docker build + port mapping works."
  });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`{{PROJECT_NAME}} listening on :${port}`);
});
"@
                }
            }
        }
        { $_ -in @("python", "py") } {
            return @{
                Port = 5000
                Files = @{
                    "Dockerfile" = @"
FROM python:3.12-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py /app/app.py

EXPOSE 5000
CMD ["python", "/app/app.py"]
"@
                    "requirements.txt" = "flask==3.0.3`n"
                    "app.py" = @"
from flask import Flask, jsonify
import os
import socket
from datetime import datetime, timezone

app = Flask(__name__)

@app.get("/")
def root():
    return jsonify({
        "project": "{{PROJECT_NAME}}",
        "language": "python",
        "hostname": socket.gethostname(),
        "time_utc": datetime.now(timezone.utc).isoformat(),
        "note": "If you can see this JSON, Docker networking + port mapping works."
    })

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)
"@
                }
            }
        }
        "web-stack" {
            return @{
                Port = 3000
                IsMultiService = $true
                Files = @{
                    "compose.yml" = @"
name: {{PROJECT_NAME}}

services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: `${DB_PASSWORD:-devpass}
      POSTGRES_USER: `${DB_USER:-devuser}
      POSTGRES_DB: `${DB_NAME:-appdb}
    volumes:
      - db-data:`/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U `${DB_USER:-devuser}"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build: ./api
    depends_on:
      db:
        condition: service_healthy
    environment:
      - PORT=8000
      - DB_HOST=db
      - DB_USER=`${DB_USER:-devuser}
      - DB_PASSWORD=`${DB_PASSWORD:-devpass}
      - DB_NAME=`${DB_NAME:-appdb}
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3

  web:
    build: ./web
    depends_on:
      api:
        condition: service_healthy
    ports:
      - "`${HOST_PORT:-{{HOST_PORT}}}:3000"
    environment:
      - PORT=3000
      - API_URL=http://api:8000
    restart: unless-stopped

volumes:
  db-data:
"@
                    "web/Dockerfile" = @"
FROM node:20-alpine

WORKDIR /app
COPY package.json /app/
RUN npm install --omit=dev

COPY server.js /app/server.js

EXPOSE 3000
ENV PORT=3000
CMD ["npm", "start"]
"@
                    "web/package.json" = @"
{
  "name": "{{PROJECT_NAME}}-web",
  "version": "1.0.0",
  "private": true,
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
"@
                    "web/server.js" = @"
const express = require("express");
const os = require("os");

const app = express();
const port = process.env.PORT || 3000;
const apiUrl = process.env.API_URL || "http://api:8000";

app.get("/", async (req, res) => {
  try {
    const response = await fetch(apiUrl + "/");
    const apiData = await response.json();

    res.json({
      project: "{{PROJECT_NAME}}",
      service: "web",
      hostname: os.hostname(),
      api_response: apiData
    });
  } catch (error) {
    res.json({
      project: "{{PROJECT_NAME}}",
      service: "web",
      hostname: os.hostname(),
      error: "Cannot connect to API"
    });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Web service listening on :`+port);
});
"@
                    "api/Dockerfile" = @"
FROM python:3.12-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py /app/app.py

EXPOSE 8000
CMD ["python", "/app/app.py"]
"@
                    "api/requirements.txt" = "flask==3.0.3`npsycopg2-binary==2.9.9`n"
                    "api/app.py" = @"
from flask import Flask, jsonify
import os
import socket
import psycopg2
from datetime import datetime, timezone

app = Flask(__name__)

def get_db_connection():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "db"),
        database=os.environ.get("DB_NAME", "appdb"),
        user=os.environ.get("DB_USER", "devuser"),
        password=os.environ.get("DB_PASSWORD", "devpass")
    )

@app.get("/")
def root():
    try:
        conn = get_db_connection()
        conn.close()
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"

    return jsonify({
        "project": "{{PROJECT_NAME}}",
        "service": "api",
        "hostname": socket.gethostname(),
        "time_utc": datetime.now(timezone.utc).isoformat(),
        "database": db_status
    })

@app.get("/health")
def health():
    return jsonify({"status": "healthy"})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="0.0.0.0", port=port)
"@
                    ".env" = "DB_USER=devuser`nDB_PASSWORD=devpass`nDB_NAME=appdb`n"
                    "README.md" = @"
# {{PROJECT_NAME}}

Multi-service web stack with:
- **web**: Node.js frontend (port {{HOST_PORT}})
- **api**: Python Flask backend (internal)
- **db**: PostgreSQL database (internal)

## Usage

Start all services:
``````powershell
.\up.ps1 {{PROJECT_NAME}} -Build
``````

Start specific services:
``````powershell
.\up.ps1 {{PROJECT_NAME}} -Services web,api
``````

View logs:
``````powershell
.\service.ps1 logs {{PROJECT_NAME}} api -Follow
``````

Test:
``````powershell
curl http://localhost:{{HOST_PORT}}
``````
"@
                }
            }
        }
        "microservice" {
            return @{
                Port = 8080
                IsMultiService = $true
                Files = @{
                    "compose.yml" = @"
name: {{PROJECT_NAME}}

x-service-common: &service-common
  restart: unless-stopped
  networks:
    - app-network

x-healthcheck-http: &healthcheck-http
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 10s

services:
  redis:
    <<: *service-common
    image: redis:7-alpine
    volumes:
      - redis-data:`/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      <<: *healthcheck-http

  service:
    <<: *service-common
    build: .
    depends_on:
      redis:
        condition: service_healthy
    ports:
      - "`${HOST_PORT:-{{HOST_PORT}}}:8080"
    environment:
      - PORT=8080
      - REDIS_HOST=redis
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
      <<: *healthcheck-http

networks:
  app-network:
    driver: bridge

volumes:
  redis-data:
"@
                    "Dockerfile" = @"
FROM golang:1.22-alpine AS builder
WORKDIR /src

RUN apk add --no-cache curl

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server .

FROM alpine:3.20
WORKDIR /app

RUN apk add --no-cache curl

COPY --from=builder /out/server /app/server

EXPOSE 8080
ENV PORT=8080
CMD ["/app/server"]
"@
                    "go.mod" = "module {{PROJECT_NAME}}`n`ngo 1.22`n`nrequire github.com/redis/go-redis/v9 v9.5.1`n"
                    "go.sum" = @"
github.com/cespare/xxhash/v2 v2.2.0 h1:DC2CZ1Ep5Y4k3ZQ899DldepgrayRUGE6BBZ/cd9Cj44=
github.com/cespare/xxhash/v2 v2.2.0/go.mod h1:VGX0DQ3Q6kWi7AoAeZDth3/j3BqPcfZpf7njtdGSn5Q=
github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f h1:lO4WD4F/rVNCu3HqELle0jiPLLBs70cWOduZpkS1E78=
github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f/go.mod h1:cuUVRXasLTGF7a8hSLbxyZXjz+1KgoB3wDUb6vlszIc=
github.com/redis/go-redis/v9 v9.5.1 h1:H1X4D3yHPaYrkL5X06Wh6xNVM/pX0Ft4RV0vMGvLBh8=
github.com/redis/go-redis/v9 v9.5.1/go.mod h1:hdY0cQFCN4fnSYT6TkisLufl/4W5UIXyv0b/CLO2V2E=
"@
                    "main.go" = @"
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

var rdb *redis.Client

type Response struct {
	Project     string ``json:"project"``
	Service     string ``json:"service"``
	TimeUTC     string ``json:"time_utc"``
	RedisStatus string ``json:"redis_status"``
}

func handler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Test Redis connection
	redisStatus := "connected"
	if err := rdb.Ping(ctx).Err(); err != nil {
		redisStatus = "error: " + err.Error()
	}

	resp := Response{
		Project:     "{{PROJECT_NAME}}",
		Service:     "microservice",
		TimeUTC:     time.Now().UTC().Format(time.RFC3339),
		RedisStatus: redisStatus,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func main() {
	redisHost := os.Getenv("REDIS_HOST")
	if redisHost == "" {
		redisHost = "localhost"
	}

	rdb = redis.NewClient(&redis.Options{
		Addr: redisHost + ":6379",
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", handler)
	mux.HandleFunc("/health", healthHandler)

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("{{PROJECT_NAME}} microservice listening on %s", srv.Addr)
	log.Fatal(srv.ListenAndServe())
}
"@
                    "README.md" = @"
# {{PROJECT_NAME}}

Microservice template with:
- **service**: Go HTTP server (port {{HOST_PORT}})
- **redis**: Redis cache (internal)

## Usage

Start all services:
``````powershell
.\up.ps1 {{PROJECT_NAME}} -Build
``````

View logs:
``````powershell
.\service.ps1 logs {{PROJECT_NAME}} service -Follow
``````

Test:
``````powershell
curl http://localhost:{{HOST_PORT}}
``````
"@
                }
            }
        }
    }
}

function New-Project {
    param(
        [string]$Name,
        [string]$Language,
        [int]$HostPort
    )

    # Validate project name
    if ($Name -notmatch '^[a-z0-9-]+$') {
        Write-Host "Error: Project name must contain only lowercase letters, numbers, and hyphens." -ForegroundColor Red
        exit 1
    }

    $projectPath = Join-Path $projectsDir $Name

    if (Test-Path $projectPath) {
        Write-Host "Error: Project '$Name' already exists." -ForegroundColor Red
        exit 1
    }

    # Normalize language name
    if ($Language -eq "py") { $Language = "python" }

    # Get language-specific settings
    $langConfig = Get-LanguageDefaults -Language $Language
    if (-not $langConfig) {
        Write-Host "Error: Unsupported template '$Language'." -ForegroundColor Red
        Write-Host "Supported templates: go, node, python, web-stack, microservice" -ForegroundColor Yellow
        exit 1
    }

    # Determine host port
    if ($HostPort -eq 0) {
        $HostPort = Get-NextAvailablePort
    }

    # Create project directory
    $isMultiService = $langConfig.ContainsKey("IsMultiService") -and $langConfig.IsMultiService

    if ($isMultiService) {
        Write-Host "Creating multi-service project: $Name ($Language)" -ForegroundColor Cyan
    } else {
        Write-Host "Creating project: $Name ($Language)" -ForegroundColor Cyan
    }
    Write-Host "  Location: $projectPath"
    Write-Host "  Host port: $HostPort -> Container port: $($langConfig.Port)"

    New-Item -ItemType Directory -Path $projectPath -Force | Out-Null

    # For single-service projects, create compose.yml
    if (-not $isMultiService) {
        $composeContent = @"
name: $Name
services:
  web:
    build: .
    ports:
      - "`${HOST_PORT:-$HostPort}:$($langConfig.Port)"
    environment:
      - PORT=$($langConfig.Port)
    restart: unless-stopped
"@
        Set-Content -Path (Join-Path $projectPath "compose.yml") -Value $composeContent
    }

    # Create language-specific files
    foreach ($file in $langConfig.Files.GetEnumerator()) {
        $filePath = Join-Path $projectPath $file.Key

        # Create parent directory if file is in subdirectory
        $parentDir = Split-Path -Parent $filePath
        if ($parentDir -and !(Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $content = $file.Value -replace '{{PROJECT_NAME}}', $Name -replace '{{HOST_PORT}}', $HostPort
        Set-Content -Path $filePath -Value $content
    }

    Write-Host ""
    Write-Host "Success! Project '$Name' created." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Start the project:  .\up.ps1 $Name -Build"
    Write-Host "  2. View logs:          docker compose -f projects\$Name\compose.yml -p $Name logs -f"
    Write-Host "  3. Test endpoint:      curl http://localhost:$HostPort"
    Write-Host "  4. Stop the project:   .\down.ps1 $Name"
    Write-Host "  5. Clean & remove:     .\run.ps1 remove $Name"
    Write-Host ""
}

function Show-Projects {
    if (!(Test-Path $projectsDir)) {
        Write-Host "No projects found." -ForegroundColor Yellow
        return
    }

    $projects = Get-ChildItem $projectsDir -Directory

    if ($projects.Count -eq 0) {
        Write-Host "No projects found." -ForegroundColor Yellow
        return
    }

    Write-Host "Available projects:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($proj in $projects) {
        $composePath = Join-Path $proj.FullName "compose.yml"
        if (Test-Path $composePath) {
            $content = Get-Content $composePath -Raw

            # Extract port
            $port = "?"
            if ($content -match '\$\{HOST_PORT:-(\d+)\}') {
                $port = $Matches[1]
            }

            # Detect language
            $lang = "?"
            if (Test-Path (Join-Path $proj.FullName "go.mod")) { $lang = "go" }
            elseif (Test-Path (Join-Path $proj.FullName "package.json")) { $lang = "node" }
            elseif (Test-Path (Join-Path $proj.FullName "requirements.txt")) { $lang = "python" }

            Write-Host ("  {0,-20} {1,-8} port {2}" -f $proj.Name, "[$lang]", $port)
        }
    }
    Write-Host ""
}

function Remove-Project {
    param(
        [string]$Name,
        [switch]$Force
    )

    # Check if project exists
    $projectPath = Join-Path $projectsDir $Name
    if (!(Test-Path $projectPath)) {
        Write-Host "Error: Project '$Name' does not exist." -ForegroundColor Red
        exit 1
    }

    Write-Host "Removing project: $Name" -ForegroundColor Yellow
    Write-Host "  Location: $projectPath"
    Write-Host ""
    Write-Host "This will:" -ForegroundColor Cyan
    Write-Host "  1. Stop and remove all Docker containers"
    Write-Host "  2. Remove Docker images and volumes"
    Write-Host "  3. Clean build cache"
    Write-Host "  4. DELETE the project folder"
    Write-Host ""

    # Call clean.ps1 with -RemoveProject
    $cleanScript = Join-Path $root "clean.ps1"
    $cleanParams = @{
        Project = $Name
        Deep = $true
        RemoveProject = $true
    }
    if ($Force) {
        $cleanParams.Force = $true
    }

    & $cleanScript @cleanParams

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Project '$Name' has been completely removed." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Error: Failed to remove project '$Name'." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# ============================================================
# Main command routing
# ============================================================

switch ($Command) {
    "new" {
        if (-not $ProjectName) {
            Write-Host "Error: Project name is required." -ForegroundColor Red
            Write-Host "Usage: .\run.ps1 new <project-name> -Lang <go|node|python> [-Port <port>]" -ForegroundColor Yellow
            exit 1
        }

        if (-not $Lang) {
            Write-Host "Error: -Lang parameter is required." -ForegroundColor Red
            Write-Host "Usage: .\run.ps1 new <project-name> -Lang <go|node|python> [-Port <port>]" -ForegroundColor Yellow
            exit 1
        }

        New-Project -Name $ProjectName -Language $Lang -HostPort $Port
    }

    "list" {
        Show-Projects
    }

    { $_ -in @("remove", "delete") } {
        if (-not $ProjectName) {
            Write-Host "Error: Project name is required." -ForegroundColor Red
            Write-Host "Usage: .\run.ps1 remove <project-name> [-Force]" -ForegroundColor Yellow
            exit 1
        }

        Remove-Project -Name $ProjectName -Force:$Force
    }

    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host "Available commands: new, list, remove" -ForegroundColor Yellow
        exit 1
    }
}
