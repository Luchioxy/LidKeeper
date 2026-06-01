#!/bin/bash
# LidKeeper for Linux
# Keep your laptop awake when AI agents are running
# https://github.com/Luchioxy/LidKeeper

set -e

# ── Configuration ──────────────────────────────────────────────────────────────

INSTALL_DIR="$HOME/.lidkeeper"
MONITOR_SCRIPT="$INSTALL_DIR/monitor.sh"
SERVICE_NAME="lidkeeper-monitor"
SERVICE_PATH="$HOME/.config/systemd/user/$SERVICE_NAME.service"
TIMER_PATH="$HOME/.config/systemd/user/$SERVICE_NAME.timer"
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

get_lid_action() {
    if [ -f /etc/systemd/logind.conf ]; then
        grep "^HandleLidSwitch=" /etc/systemd/logind.conf 2>/dev/null | cut -d= -f2 || echo "suspend"
    else
        echo "suspend"
    fi
}

# ── Mode Implementations ──────────────────────────────────────────────────────

install_smart_mode() {
    echo -e "  ${CYAN}[Smart Mode] Configuring...${NC}"
    echo ""

    # Create install directory
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$HOME/.config/systemd/user"

    # Save original settings
    if [ -f /etc/systemd/logind.conf ]; then
        cp /etc/systemd/logind.conf "$INSTALL_DIR/logind.conf.bak" 2>/dev/null || true
    fi

    # Create monitor script
    cat > "$MONITOR_SCRIPT" << 'EOF'
#!/bin/bash
# LidKeeper Monitor for Linux
# Called by systemd timer every 60 seconds

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
    # Agents running - prevent idle sleep
    systemd-inhibit --what=idle:sleep --who=LidKeeper --why="AI Agent running" sleep infinity &
    echo $! > "$INSTALL_DIR/inhibit.pid"
    log "Agents running - preventing sleep (PID: $!)"
else
    # No agents - allow sleep
    if [ -f "$INSTALL_DIR/inhibit.pid" ]; then
        kill "$(cat "$INSTALL_DIR/inhibit.pid")" 2>/dev/null || true
        rm -f "$INSTALL_DIR/inhibit.pid"
    fi
    log "No agents - allowing sleep"
fi
EOF

    chmod +x "$MONITOR_SCRIPT"

    # Create systemd service
    cat > "$SERVICE_PATH" << EOF
[Unit]
Description=LidKeeper Monitor - Prevent sleep when AI agents running

[Service]
Type=oneshot
ExecStart=$MONITOR_SCRIPT
EOF

    # Create systemd timer
    cat > "$TIMER_PATH" << EOF
[Unit]
Description=Run LidKeeper monitor every 60 seconds

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOF

    # Enable and start the timer
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME.timer"
    systemctl --user start "$SERVICE_NAME.timer"

    # If agents are running now, prevent sleep immediately
    if check_agents_running; then
        systemd-inhibit --what=idle:sleep --who=LidKeeper --why="AI Agent running" sleep infinity &
        echo $! > "$INSTALL_DIR/inhibit.pid"
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

    # Check if we can modify logind.conf
    if [ -w /etc/systemd/logind.conf ]; then
        # Backup original
        cp /etc/systemd/logind.conf /etc/systemd/logind.conf.bak

        # Set lid close to ignore
        sed -i 's/^HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf

        # Add if not exists
        if ! grep -q "^HandleLidSwitch=" /etc/systemd/logind.conf; then
            echo "HandleLidSwitch=ignore" >> /etc/systemd/logind.conf
        fi

        # Restart logind
        sudo systemctl restart systemd-logind

        echo -e "  ${GREEN}Lid close action set to 'ignore'.${NC}"
    else
        echo -e "  ${YELLOW}Need sudo to modify /etc/systemd/logind.conf${NC}"
        echo ""
        sudo bash -c '
            cp /etc/systemd/logind.conf /etc/systemd/logind.conf.bak
            sed -i "s/^HandleLidSwitch=.*/HandleLidSwitch=ignore/" /etc/systemd/logind.conf
            if ! grep -q "^HandleLidSwitch=" /etc/systemd/logind.conf; then
                echo "HandleLidSwitch=ignore" >> /etc/systemd/logind.conf
            fi
            systemctl restart systemd-logind
        '
        echo -e "  ${GREEN}Lid close action set to 'ignore'.${NC}"
    fi

    echo ""
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Always-On Mode enabled!${NC}"
    echo ""
    echo "  Lid close will not cause sleep."
    echo "  To restore: sudo sed -i 's/HandleLidSwitch=ignore/HandleLidSwitch=suspend/' /etc/systemd/logind.conf"
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
}

uninstall_all() {
    echo -e "  ${CYAN}[Uninstall] Cleaning up...${NC}"
    echo ""

    # Stop and disable timer
    systemctl --user stop "$SERVICE_NAME.timer" 2>/dev/null || true
    systemctl --user disable "$SERVICE_NAME.timer" 2>/dev/null || true

    # Remove service and timer files
    rm -f "$SERVICE_PATH"
    rm -f "$TIMER_PATH"

    # Kill any running inhibit
    if [ -f "$INSTALL_DIR/inhibit.pid" ]; then
        kill "$(cat "$INSTALL_DIR/inhibit.pid")" 2>/dev/null || true
        rm -f "$INSTALL_DIR/inhibit.pid"
    fi

    # Restore original logind.conf if backup exists
    if [ -f "$INSTALL_DIR/logind.conf.bak" ]; then
        sudo cp "$INSTALL_DIR/logind.conf.bak" /etc/systemd/logind.conf
        sudo systemctl restart systemd-logind
        echo -e "  ${GREEN}Restored original logind.conf${NC}"
    fi

    # Reload systemd
    systemctl --user daemon-reload

    # Remove install directory
    rm -rf "$INSTALL_DIR"

    echo -e "  ${GREEN}Removed systemd timer and service.${NC}"
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

if systemctl --user is-active "$SERVICE_NAME.timer" > /dev/null 2>&1; then
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
