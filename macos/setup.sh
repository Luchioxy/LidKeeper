#!/bin/bash
# LidKeeper for macOS
# Keep your laptop awake when AI agents are running
# https://github.com/Luchioxy/LidKeeper

set -e

# ── Configuration ──────────────────────────────────────────────────────────────

INSTALL_DIR="$HOME/.lidkeeper"
MONITOR_SCRIPT="$INSTALL_DIR/monitor.sh"
PID_FILE="$INSTALL_DIR/caffeinate.pid"
PLIST_NAME="com.lidkeeper.monitor"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
LOG_FILE="$INSTALL_DIR/lidkeeper.log"

# Default agent process names (case-sensitive on macOS)
DEFAULT_AGENT_PROCESSES=("claude" "Codex" "WorkBuddy")

# Load agents from config file, or use defaults
load_agents() {
    local conf="$INSTALL_DIR/agents.conf"
    if [ -f "$conf" ]; then
        AGENT_PROCESSES=()
        while IFS= read -r line; do
            line=$(echo "$line" | xargs)  # trim whitespace
            [ -n "$line" ] && AGENT_PROCESSES+=("$line")
        done < "$conf"
    else
        AGENT_PROCESSES=("${DEFAULT_AGENT_PROCESSES[@]}")
    fi
}

save_agents() {
    mkdir -p "$INSTALL_DIR"
    printf '%s\n' "${AGENT_PROCESSES[@]}" > "$INSTALL_DIR/agents.conf"
}

# ── Colors ─────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Helper Functions ───────────────────────────────────────────────────────────

print_banner() {
    echo ""
    echo -e "${CYAN}  ╔═══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║           LidKeeper v1.0                  ║${NC}"
    echo -e "${CYAN}  ║       No Sleep for AI Agents              ║${NC}"
    echo -e "${CYAN}  ╚═══════════════════════════════════════════╝${NC}"
    echo ""
}

check_agents_running() {
    for proc in "${AGENT_PROCESSES[@]}"; do
        if pgrep -x "$proc" > /dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Load agent list from config (or use defaults)
load_agents

# ── Mode Implementations ──────────────────────────────────────────────────────

install_smart_mode() {
    echo -e "  ${CYAN}[Smart Mode] Configuring...${NC}"
    echo ""

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Save original pmset settings for restore
    pmset -g | grep -E "^\s*(sleep|disablesleep|disksleep)" > "$INSTALL_DIR/original_smart_pmset.txt" 2>/dev/null || true
    echo "smart" > "$INSTALL_DIR/current_mode"

    # Save agent process list to config
    save_agents

    # Create monitor script with proper PID tracking
    cat > "$MONITOR_SCRIPT" << 'EOF'
#!/bin/bash
# LidKeeper Monitor for macOS
# Called by LaunchAgent every 60 seconds

INSTALL_DIR="$HOME/.lidkeeper"
PID_FILE="$INSTALL_DIR/caffeinate.pid"
LOG_FILE="$INSTALL_DIR/lidkeeper.log"

# Load agents from config file, or use defaults
AGENT_PROCESSES=()
if [ -f "$INSTALL_DIR/agents.conf" ]; then
    while IFS= read -r line; do
        line=$(echo "$line" | xargs)  # trim whitespace
        [ -n "$line" ] && AGENT_PROCESSES+=("$line")
    done < "$INSTALL_DIR/agents.conf"
fi
if [ ${#AGENT_PROCESSES[@]} -eq 0 ]; then
    AGENT_PROCESSES=("claude" "Codex" "WorkBuddy")
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

# Kill tracked caffeinate process if it exists
kill_tracked() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
}

check_agents_running() {
    for proc in "${AGENT_PROCESSES[@]}"; do
        if pgrep -x "$proc" > /dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Check if tracked process is still alive
is_tracked_alive() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$PID_FILE"
    fi
    return 1
}

if check_agents_running; then
    # Only start new caffeinate if not already running
    if ! is_tracked_alive; then
        caffeinate -i -s &
        echo $! > "$PID_FILE"
        log "Agents running - started caffeinate (PID: $!)"
    fi
else
    # No agents - stop preventing sleep
    kill_tracked
    log "No agents - allowing sleep"
fi
EOF

    chmod +x "$MONITOR_SCRIPT"

    # Create LaunchAgent plist
    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$MONITOR_SCRIPT</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
</dict>
</plist>
EOF

    # Load the LaunchAgent (use modern bootstrap if available)
    if command -v launchctl &> /dev/null; then
        launchctl bootstrap gui/$(id -u) "$PLIST_PATH" 2>/dev/null || launchctl load "$PLIST_PATH" 2>/dev/null || true
    fi

    # If agents are running now, prevent sleep immediately
    if check_agents_running; then
        caffeinate -i -s &
        echo $! > "$PID_FILE"
        echo -e "  ${GREEN}Agent(s) detected, sleep prevented now.${NC}"
    fi

    echo ""
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Smart Mode enabled!${NC}"
    echo ""
    echo "  Monitor runs every 60 seconds:"
    echo "    - Agent running -> no sleep on lid close"
    echo "    - No agent      -> restore normal behavior"
    echo ""
    echo "  Log file: $LOG_FILE"
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
}

install_always_on_mode() {
    echo -e "  ${CYAN}[Always-On Mode] Configuring...${NC}"
    echo ""

    # Save original settings before modifying
    mkdir -p "$INSTALL_DIR"
    pmset -g | grep -E "^\s*(lidwake|autopoweroff|standby)" > "$INSTALL_DIR/original_always_pmset.txt" 2>/dev/null || true
    echo "always" > "$INSTALL_DIR/current_mode"

    # Save agent process list to config
    save_agents

    # Prevent sleep on lid close only (keep idle sleep working)
    sudo pmset -a lidwake 1
    sudo pmset -a autopoweroff 0
    sudo pmset -a standby 0

    echo ""
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Always-On Mode enabled!${NC}"
    echo ""
    echo "  Lid close will not cause sleep."
    echo "  Idle sleep still works normally."
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
}

uninstall_all() {
    echo -e "  ${CYAN}[Uninstall] Cleaning up...${NC}"
    echo ""

    # Unload LaunchAgent (use modern bootout if available)
    if [ -f "$PLIST_PATH" ]; then
        launchctl bootout gui/$(id -u)/$PLIST_NAME 2>/dev/null || launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        echo -e "  ${GREEN}Removed LaunchAgent.${NC}"
    fi

    # Kill tracked caffeinate process
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi

    # Restore original settings based on which mode was installed
    local restored=false
    local mode_file="$INSTALL_DIR/current_mode"
    local backup_file=""

    if [ -f "$mode_file" ]; then
        local mode
        mode=$(cat "$mode_file")
        if [ "$mode" = "smart" ] && [ -f "$INSTALL_DIR/original_smart_pmset.txt" ]; then
            backup_file="$INSTALL_DIR/original_smart_pmset.txt"
        elif [ "$mode" = "always" ] && [ -f "$INSTALL_DIR/original_always_pmset.txt" ]; then
            backup_file="$INSTALL_DIR/original_always_pmset.txt"
        fi
    fi

    # Fallback: try whichever backup file exists
    if [ -z "$backup_file" ]; then
        if [ -f "$INSTALL_DIR/original_smart_pmset.txt" ]; then
            backup_file="$INSTALL_DIR/original_smart_pmset.txt"
        elif [ -f "$INSTALL_DIR/original_always_pmset.txt" ]; then
            backup_file="$INSTALL_DIR/original_always_pmset.txt"
        fi
    fi

    if [ -n "$backup_file" ]; then
        while IFS= read -r line; do
            key=$(echo "$line" | awk '{print $1}')
            value=$(echo "$line" | awk '{print $2}')
            if [ -n "$key" ] && [ -n "$value" ]; then
                sudo pmset -a "$key" "$value" 2>/dev/null || true
            fi
        done < "$backup_file"
        restored=true
        echo -e "  ${GREEN}Restored original sleep settings.${NC}"
    fi

    if [ "$restored" = false ]; then
        echo -e "  ${YELLOW}No original settings found, skipped restore.${NC}"
    fi

    # Remove install directory
    rm -rf "$INSTALL_DIR"
    echo -e "  ${GREEN}Cleaned up installation files.${NC}"

    echo ""
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Uninstall complete!${NC}"
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
}

configure_agents() {
    echo ""
    echo "  Current monitored processes:"
    for proc in "${AGENT_PROCESSES[@]}"; do
        echo "    - $proc"
    done
    echo ""
    echo "  Enter new process names (one per line, empty line to finish):"
    echo "  Leave blank and press Enter to keep current list."
    echo ""
    local new_agents=()
    while true; do
        read -p "  > " proc
        [ -z "$proc" ] && break
        new_agents+=("$proc")
    done
    if [ ${#new_agents[@]} -gt 0 ]; then
        AGENT_PROCESSES=("${new_agents[@]}")
        save_agents
        echo ""
        echo -e "  ${GREEN}Saved ${#AGENT_PROCESSES[@]} process(es).${NC}"
    else
        echo "  No changes."
    fi
    echo ""
}

show_status() {
    echo "  Current Status:"
    if [ -f "$PLIST_PATH" ] || [ -f "$INSTALL_DIR/agents.conf" ]; then
        load_agents
        if check_agents_running; then
            echo -e "    Running agents: ${GREEN}Yes${NC}"
        else
            echo -e "    Running agents: ${RED}No${NC}"
        fi
    fi

    if [ -f "$PLIST_PATH" ]; then
        echo -e "    Monitor: ${GREEN}Active${NC}"
    else
        echo -e "    Monitor: ${RED}Inactive${NC}"
    fi
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

print_banner
show_status

while true; do
    echo "  Select mode:"
    echo ""
    echo "    [1] Smart Mode  - No sleep only when agents run"
    echo "    [2] Always-On   - Never sleep on lid close"
    echo "    [3] Uninstall   - Remove all settings"
    echo "    [4] Configure Agents  - Manage monitored process list"
    echo "    [0] Exit"
    echo ""

    read -p "  Choose (0-4): " choice

    case $choice in
        1) install_smart_mode ;;
        2) install_always_on_mode ;;
        3) uninstall_all ;;
        4) configure_agents ;;
        0) echo "  Goodbye!"; exit 0 ;;
        *) echo -e "  ${RED}Invalid choice.${NC}" ;;
    esac

    show_status
done
