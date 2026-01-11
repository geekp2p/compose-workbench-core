#!/bin/bash
# ============================================================
# help.sh
# Display help information for multi-compose-lab (Bash version)
# ============================================================

TOPIC="${1:-}"

show_header() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Multi-Compose Lab - Help & Quick Reference"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
}

show_quick_start() {
  echo -e "\033[1;32mQuick Start Guide:\033[0m"
  echo ""
  echo -e "\033[1;33m  1. Create a new project:\033[0m"
  echo "     ./run.ps1 new my-app -Lang node"
  echo ""
  echo -e "\033[1;33m  2. Start your project:\033[0m"
  echo "     ./up.ps1 my-app -Build"
  echo ""
  echo -e "\033[1;33m  3. Test it:\033[0m"
  echo "     curl http://localhost:8001"
  echo ""
  echo -e "\033[1;33m  4. Stop your project:\033[0m"
  echo "     ./down.ps1 my-app"
  echo ""
}

show_main_commands() {
  echo -e "\033[1;32mMain Commands:\033[0m"
  echo ""

  echo -e "\033[1;36m  Project Management:\033[0m"
  echo "    ./run.ps1 new <name> -Lang <go|node|python>"
  echo "      Create a new project with specified language"
  echo ""
  echo "    ./run.ps1 list"
  echo "      List all available projects"
  echo ""
  echo "    ./run.ps1 remove <name>"
  echo "      Completely remove a project (Docker + files)"
  echo ""

  echo -e "\033[1;36m  Docker Operations:\033[0m"
  echo "    ./up.ps1 <project> [-Build]"
  echo "      Start a project (use -Build for first time or after code changes)"
  echo ""
  echo "    ./down.ps1 <project>"
  echo "      Stop a running project"
  echo ""

  echo -e "\033[1;36m  Cleanup:\033[0m"
  echo "    ./clean.ps1 -Project <name>"
  echo "      Stop and remove containers/network"
  echo ""
  echo "    ./clean.ps1 -Project <name> -Deep"
  echo "      Also remove images and volumes (more thorough)"
  echo ""
  echo "    ./clean.ps1 -All"
  echo "      Clean all unused Docker resources (safe)"
  echo ""
  echo "    ./clean.ps1 -All -Deep"
  echo "      Clean everything including volumes (WARNING: destructive!)"
  echo ""

  echo -e "\033[1;36m  Help:\033[0m"
  echo "    ./help.ps1"
  echo "      Show this help message"
  echo ""
  echo "    ./help.ps1 <topic>"
  echo "      Show detailed help for: start, stop, clean, new, list, remove"
  echo ""
}

show_examples() {
  echo -e "\033[1;32mCommon Examples:\033[0m"
  echo ""

  echo -e "\033[1;33m  Create & run a Node.js project:\033[0m"
  echo "    ./run.ps1 new my-api -Lang node"
  echo "    ./up.ps1 my-api -Build"
  echo ""

  echo -e "\033[1;33m  Create a Go project on custom port:\033[0m"
  echo "    ./run.ps1 new go-service -Lang go -Port 9000"
  echo "    ./up.ps1 go-service -Build"
  echo ""

  echo -e "\033[1;33m  Create a Python project:\033[0m"
  echo "    ./run.ps1 new py-app -Lang python"
  echo "    ./up.ps1 py-app -Build"
  echo ""

  echo -e "\033[1;33m  View all projects:\033[0m"
  echo "    ./run.ps1 list"
  echo ""

  echo -e "\033[1;33m  Stop a project:\033[0m"
  echo "    ./down.ps1 my-api"
  echo ""

  echo -e "\033[1;33m  Clean up after testing:\033[0m"
  echo "    ./clean.ps1 -Project my-api -Deep"
  echo ""

  echo -e "\033[1;33m  Completely remove a project:\033[0m"
  echo "    ./run.ps1 remove my-api"
  echo ""

  echo -e "\033[1;33m  Free up disk space:\033[0m"
  echo "    ./clean.ps1 -All -Deep -Force"
  echo ""
}

show_available_projects() {
  if [ ! -d "projects" ]; then
    echo -e "\033[1;33mNo projects directory found.\033[0m"
    return
  fi

  local count=$(find projects -maxdepth 1 -type d | wc -l)
  if [ "$count" -le 1 ]; then
    echo -e "\033[1;33mNo projects found. Create one with:\033[0m"
    echo "  ./run.ps1 new <name> -Lang <go|node|python>"
    return
  fi

  echo -e "\033[1;32mAvailable Projects:\033[0m"
  echo ""
  printf "  %-20s %-10s %s\n" "Name" "Language" "Port"
  printf "  %-20s %-10s %s\n" "----" "--------" "----"

  for project_dir in projects/*/; do
    if [ -d "$project_dir" ]; then
      local name=$(basename "$project_dir")
      local compose_file="${project_dir}compose.yml"

      if [ -f "$compose_file" ]; then
        # Extract port
        local port=$(grep -oP '\$\{HOST_PORT:-\K\d+' "$compose_file" 2>/dev/null || echo "?")

        # Detect language
        local lang="?"
        [ -f "${project_dir}go.mod" ] && lang="go"
        [ -f "${project_dir}package.json" ] && lang="node"
        [ -f "${project_dir}requirements.txt" ] && lang="python"

        printf "  %-20s %-10s %s\n" "$name" "$lang" "$port"
      fi
    fi
  done
  echo ""
}

show_tips() {
  echo -e "\033[1;32mHelpful Tips:\033[0m"
  echo ""

  echo -e "\033[1;33m  View logs:\033[0m"
  echo "    docker compose -f projects/<name>/compose.yml -p <name> logs -f"
  echo ""

  echo -e "\033[1;33m  Check running containers:\033[0m"
  echo "    docker compose -f projects/<name>/compose.yml -p <name> ps"
  echo ""

  echo -e "\033[1;33m  Test your service:\033[0m"
  echo "    curl http://localhost:<port>"
  echo "    # or open in browser"
  echo ""

  echo -e "\033[1;33m  Check disk usage:\033[0m"
  echo "    docker system df"
  echo ""

  echo -e "\033[1;33m  PowerShell vs CMD:\033[0m"
  echo "    PowerShell: ./help.ps1, ./up.ps1, etc."
  echo "    CMD:        help, up <project>, etc."
  echo ""
}

show_footer() {
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "  For more help on a specific topic:"
  echo "    ./help.ps1 <topic>  (start|stop|clean|new|list|remove)"
  echo ""
  echo "  Project repository: multi-compose-lab"
  echo ""
}

# Main
if [ -z "$TOPIC" ]; then
  show_header
  show_quick_start
  echo ""
  show_available_projects
  echo ""
  show_main_commands
  show_examples
  show_tips
  show_footer
else
  show_header
  echo "For detailed topic help, use the PowerShell version:"
  echo "  ./help.ps1 $TOPIC"
  echo ""
fi
