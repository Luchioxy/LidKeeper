#!/bin/bash
# LidKeeper for macOS
# Keep your laptop awake when AI agents are running
# https://github.com/Luchioxy/LidKeeper

set -e

# ── Configuration ──────────────────────────────────────────────────────────────

INSTALL_DIR="$HOME/.lidkeeper"
MONITOR_SCRIPT="$INSTALL_DIR/monitor.sh"
PLIST_NAME="com.lidkeeper.monitor"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
LOG_FILE="$INSTALL_DIR/lidkeeper.log"

# Agent process names
AGENT_PROCESSES=("claude" "codex" "WorkBuddy")

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

get_current_lid_action() {
    # Check if lid close causes sleep
    if pmset -g | grep -q "SleepOnPowerButton 1"; then
        echo "sleep"
    else
        echo "none"
    fi
}

# ── Mode Implementations ──────────────────────────────────────────────────────

install_smart_mode() {
    echo -e "  ${CYAN}[Smart Mode] Configuring...${NC}"
    echo ""

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Save original settings
    pmset -g > "$INSTALL_DIR/original_pmset.txt" 2>/dev/null || true

    # Create monitor script
    cat > "$MONITOR_SCRIPT" << 'EOF'
#!/bin/bash
# LidKeeper Monitor for macOS
# Called by LaunchAgent every 60 seconds

INSTALL_DIR="$HOME/.lidkeeper"
LOG_FILE="$INSTALL_DIR/lidkeeper.log"
AGENT_PROCESSES=("claude" "codex" "WorkBuddy")

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

check_agents_running() {
    for proc in "${AGENT_PROCESSES[@]}"; do
        if pgrep -x "$proc" > /dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

if check_agents_running; then
    # Agents running - prevent sleep
    caffeinate -i -s -w $$ &
    log "Agents running - preventing sleep"
else
    # No agents - allow sleep
    pkill -f "caffeinate" 2>/dev/null || true
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

    # Load the LaunchAgent
    launchctl load "$PLIST_PATH" 2>/dev/null || true

    # If agents are running now, prevent sleep immediately
    if check_agents_running; then
        caffeinate -i -s &
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

    # Prevent all sleep
    sudo pmset -a disablesleep 1
    sudo pmset -a sleep 0

    echo ""
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Always-On Mode enabled!${NC}"
    echo ""
    echo "  System sleep disabled permanently."
    echo "  To re-enable: sudo pmset -a disablesleep 0"
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
}

uninstall_all() {
    echo -e "  ${CYAN}[Uninstall] Cleaning up...${NC}"
    echo ""

    # Unload LaunchAgent
    if [ -f "$PLIST_PATH" ]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        echo -e "  ${GREEN}Removed LaunchAgent.${NC}"
    fi

    # Kill any running caffeinate
    pkill -f "caffeinate" 2>/dev/null || true

    # Restore original settings if available
    if [ -f "$INSTALL_DIR/original_pmset.txt" ]; then
        sudo pmset -a disablesleep 0
        sudo pmset -a sleep 1
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
