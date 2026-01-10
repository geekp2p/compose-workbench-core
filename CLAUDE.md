# Repo: multi-compose-lab

## Goal
Refactor + standardize scripts and compose files while keeping behavior unchanged.

## Structure
- Root scripts: up.ps1/down.ps1/clean.ps1 and cmd wrappers
- Projects live in ./projects/*
  - go-hello, node-hello, py-hello, solo-node

## How to run
- Start: .\up.ps1 <project> -Build
- Stop:  .\down.ps1 <project>
- Clean: .\clean.ps1 -Project <project> [-Deep] [-Force]

## Rules
- Do not change exposed ports unless requested.
- Prefer backward-compatible refactors.
- Always show diffs; do not auto-accept large changes.
- If editing PowerShell, keep it compatible with Windows PowerShell + PowerShell 7.