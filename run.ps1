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
  [ValidateSet("go", "node", "python", "py")]
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
        Write-Host "Error: Unsupported language '$Language'." -ForegroundColor Red
        Write-Host "Supported languages: go, node, python" -ForegroundColor Yellow
        exit 1
    }

    # Determine host port
    if ($HostPort -eq 0) {
        $HostPort = Get-NextAvailablePort
    }

    # Create project directory
    Write-Host "Creating project: $Name ($Language)" -ForegroundColor Cyan
    Write-Host "  Location: $projectPath"
    Write-Host "  Host port: $HostPort -> Container port: $($langConfig.Port)"

    New-Item -ItemType Directory -Path $projectPath -Force | Out-Null

    # Create compose.yml
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

    # Create language-specific files
    foreach ($file in $langConfig.Files.GetEnumerator()) {
        $content = $file.Value -replace '{{PROJECT_NAME}}', $Name
        Set-Content -Path (Join-Path $projectPath $file.Key) -Value $content
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
    $cleanParams = @("-Project", $Name, "-Deep", "-RemoveProject")
    if ($Force) {
        $cleanParams += "-Force"
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
