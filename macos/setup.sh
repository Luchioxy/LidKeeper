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

# Agent process names (case-sensitive on macOS)
AGENT_PROCESSES=("claude" "Codex" "WorkBuddy")

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

# ── Mode Implementations ──────────────────────────────────────────────────────

install_smart_mode() {
    echo -e "  ${CYAN}[Smart Mode] Configuring...${NC}"
    echo ""

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Save original pmset settings for restore
    pmset -g | grep -E "^\s*(sleep|disablesleep|disksleep)" > "$INSTALL_DIR/original_pmset.txt" 2>/dev/null || true

    # Create monitor script with proper PID tracking
    cat > "$MONITOR_SCRIPT" << 'EOF'
#!/bin/bash
# LidKeeper Monitor for macOS
# Called by LaunchAgent every 60 seconds

INSTALL_DIR="$HOME/.lidkeeper"
PID_FILE="$INSTALL_DIR/caffeinate.pid"
LOG_FILE="$INSTALL_DIR/lidkeeper.log"
AGENT_PROCESSES=("claude" "Codex" "WorkBuddy")

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
    pmset -g | grep -E "^\s*(lidwake|autopoweroff|standby)" > "$INSTALL_DIR/original_pmset.txt" 2>/dev/null || true

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

    # Restore original settings
    if [ -f "$INSTALL_DIR/original_pmset.txt" ]; then
        # Parse and restore each saved setting
        while IFS= read -r line; do
            key=$(echo "$line" | awk '{print $1}')
            value=$(echo "$line" | awk '{print $2}')
            if [ -n "$key" ] && [ -n "$value" ]; then
                sudo pmset -a "$key" "$value" 2>/dev/null || true
            fi
        done < "$INSTALL_DIR/original_pmset.txt"
        echo -e "  ${GREEN}Restored original sleep settings.${NC}"
    else
        # Fallback: restore defaults
        sudo pmset -a disablesleep 0 2>/dev/null || true
        sudo pmset -a sleep 1 2>/dev/null || true
        echo -e "  ${GREEN}Restored default sleep settings.${NC}"
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

# ── Main ──────────────────────────────────────────────────────────────────────

print_banner

echo "  Current Status:"
if check_agents_running; then
    echo -e "    Running agents: ${GREEN}Yes${NC}"
else
    echo -e "    Running agents: ${RED}No${NC}"
fi

if [ -f "$PLIST_PATH" ]; then
    echo -e "    Monitor: ${GREEN}Active${NC}"
else
    echo -e "    Monitor: ${RED}Inactive${NC}"
fi

echo ""
echo "  Select mode:"
echo ""
echo "    [1] Smart Mode  - No sleep only when agents run"
echo "    [2] Always-On   - Never sleep on lid close"
echo "    [3] Uninstall   - Remove all settings"
echo "    [0] Exit"
echo ""

read -p "  Choose (0-3): " choice

case $choice in
    1) install_smart_mode ;;
    2) install_always_on_mode ;;
    3) uninstall_all ;;
    0) echo "  Goodbye!"; exit 0 ;;
    *) echo -e "  ${RED}Invalid choice.${NC}"; exit 1 ;;
esac
