#!/bin/bash
# LidKeeper for Linux
# Keep your laptop awake when AI agents are running
# https://github.com/Luchioxy/LidKeeper

set -e

# ── Configuration ──────────────────────────────────────────────────────────────

INSTALL_DIR="$HOME/.lidkeeper"
MONITOR_SCRIPT="$INSTALL_DIR/monitor.sh"
PID_FILE="$INSTALL_DIR/inhibit.pid"
SERVICE_NAME="lidkeeper-monitor"
SERVICE_PATH="$HOME/.config/systemd/user/$SERVICE_NAME.service"
TIMER_PATH="$HOME/.config/systemd/user/$SERVICE_NAME.timer"
LOG_FILE="$INSTALL_DIR/lidkeeper.log"
ASSUME_YES=false

# Default agent process names (case-sensitive on Linux)
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

kill_lidkeeper_inhibit() {
    pkill -f "lidkeeper-inhibit" 2>/dev/null || true
    pkill -f "systemd-inhibit .*--who=LidKeeper" 2>/dev/null || true
}

# Load agent list from config (or use defaults)
load_agents

# ── Mode Implementations ──────────────────────────────────────────────────────

install_smart_mode() {
    echo -e "  ${CYAN}[Smart Mode] Configuring...${NC}"
    echo ""

    # Create install directory
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$HOME/.config/systemd/user"

    # Save agent process list to config
    save_agents

    # Create monitor script with proper lid-switch inhibition
    cat > "$MONITOR_SCRIPT" << 'EOF'
#!/bin/bash
# LidKeeper Monitor for Linux
# Called by systemd timer every 60 seconds

INSTALL_DIR="$HOME/.lidkeeper"
PID_FILE="$INSTALL_DIR/inhibit.pid"
LOG_FILE="$INSTALL_DIR/lidkeeper.log"
LOCK_DIR="$INSTALL_DIR/monitor.lock"

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

acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "$$" > "$LOCK_DIR/pid"
        trap 'rm -rf "$LOCK_DIR"' EXIT
        return 0
    fi

    local lock_pid
    lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
    if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
        rm -rf "$LOCK_DIR"
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            echo "$$" > "$LOCK_DIR/pid"
            trap 'rm -rf "$LOCK_DIR"' EXIT
            return 0
        fi
    fi

    exit 0
}

# Kill tracked inhibit process if it exists
kill_tracked() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            local args
            args=$(ps -p "$pid" -o args= 2>/dev/null || true)
            if [[ "$args" == *"lidkeeper-inhibit"* || "$args" == *"systemd-inhibit --what=idle:sleep:handle-lid-switch --who=LidKeeper"* ]]; then
                kill "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi
}

kill_lidkeeper_inhibit() {
    pkill -f "lidkeeper-inhibit" 2>/dev/null || true
    pkill -f "systemd-inhibit .*--who=LidKeeper" 2>/dev/null || true
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
            local args
            args=$(ps -p "$pid" -o args= 2>/dev/null || true)
            if [[ "$args" == *"lidkeeper-inhibit"* || "$args" == *"systemd-inhibit --what=idle:sleep:handle-lid-switch --who=LidKeeper"* ]]; then
                return 0
            fi
        fi
        rm -f "$PID_FILE"
    fi
    return 1
}

acquire_lock

if check_agents_running; then
    # Only start new inhibit if not already running
    if ! is_tracked_alive; then
        bash -c 'exec -a lidkeeper-inhibit systemd-inhibit --what=idle:sleep:handle-lid-switch --who=LidKeeper --why="AI Agent running" sleep infinity' &
        echo $! > "$PID_FILE"
        log "Agents running - started inhibit (PID: $!)"
    fi
else
    # No agents - allow sleep
    kill_tracked
    kill_lidkeeper_inhibit
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

    # If agents are running now, prevent sleep immediately
    if check_agents_running; then
        "$MONITOR_SCRIPT"
        echo -e "  ${GREEN}Agent(s) detected, sleep prevented now.${NC}"
    fi

    # Enable and start the timer
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME.timer"
    systemctl --user start "$SERVICE_NAME.timer"

    # Enable linger so timer survives user logout
    sudo -n loginctl enable-linger "$(whoami)" 2>/dev/null || true

    echo ""
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Smart Mode enabled!${NC}"
    echo ""
    echo "  Monitor runs every 60 seconds:"
    echo "    - Agent running -> sleep is prevented"
    echo "    - No agent      -> restore normal behavior"
    echo ""
    echo "  Log file: $LOG_FILE"
    echo -e "  ${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
}

install_always_on_mode() {
    echo -e "  ${CYAN}[Always-On Mode] Configuring...${NC}"
    echo ""

    # Create install directory for backup
    mkdir -p "$INSTALL_DIR"

    # Save agent process list to config
    save_agents

    # Check if we can modify logind.conf
    echo -e "  ${YELLOW}Warning: This modifies /etc/systemd/logind.conf (system-wide).${NC}"
    echo -e "  ${YELLOW}Restarting systemd-logind will briefly disconnect active sessions.${NC}"
    echo ""
    if [ "$ASSUME_YES" != true ]; then
        if ! read -r -p "  Continue? [y/N]: " confirm; then
            echo ""
            echo -e "  ${RED}No input available. Run this script from an interactive terminal.${NC}"
            return
        fi
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "  Cancelled."
            return
        fi
    fi
    echo ""

    if [ -w /etc/systemd/logind.conf ]; then
        # Backup original to our install dir
        cp /etc/systemd/logind.conf "$INSTALL_DIR/logind.conf.bak"

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
        sudo bash -c "
            cp /etc/systemd/logind.conf '$INSTALL_DIR/logind.conf.bak'
            sed -i 's/^HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
            if ! grep -q '^HandleLidSwitch=' /etc/systemd/logind.conf; then
                echo 'HandleLidSwitch=ignore' >> /etc/systemd/logind.conf
            fi
            systemctl restart systemd-logind
        "
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

    # Kill tracked inhibit process
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            local args
            args=$(ps -p "$pid" -o args= 2>/dev/null || true)
            if [[ "$args" == *"lidkeeper-inhibit"* || "$args" == *"systemd-inhibit --what=idle:sleep:handle-lid-switch --who=LidKeeper"* ]]; then
                kill "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi
    kill_lidkeeper_inhibit

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
        if ! read -r -p "  > " proc; then
            break
        fi
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
    local timer_active=false
    if systemctl --user is-active "$SERVICE_NAME.timer" > /dev/null 2>&1; then
        timer_active=true
    fi

    if [ "$timer_active" = true ] || [ -f "$INSTALL_DIR/agents.conf" ]; then
        load_agents
        if check_agents_running; then
            echo -e "    Running agents: ${GREEN}Yes${NC}"
        else
            echo -e "    Running agents: ${RED}No${NC}"
        fi
    fi

    if [ "$timer_active" = true ]; then
        echo -e "    Monitor: ${GREEN}Active${NC}"
    else
        echo -e "    Monitor: ${RED}Inactive${NC}"
    fi
    echo ""
}

show_help() {
    echo "Usage: setup.sh [--smart|--always|--uninstall|--help]"
    echo ""
    echo "Options:"
    echo "  --smart      Enable Smart Mode"
    echo "  --always     Enable Always-On Mode"
    echo "  --uninstall  Remove LidKeeper settings"
    echo "  --help       Show this help"
    echo ""
    echo "Without an option, setup.sh opens the interactive menu."
}

# ── Main ──────────────────────────────────────────────────────────────────────

case "${1:-}" in
    --smart|smart|1)
        print_banner
        install_smart_mode
        show_status
        exit 0
        ;;
    --always|always|2)
        ASSUME_YES=true
        print_banner
        install_always_on_mode
        show_status
        exit 0
        ;;
    --uninstall|uninstall|3)
        print_banner
        uninstall_all
        exit 0
        ;;
    --help|-h|help)
        show_help
        exit 0
        ;;
    "")
        ;;
    *)
        echo -e "  ${RED}Unknown option: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

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

    if ! read -r -p "  Choose (0-4): " choice; then
        echo ""
        echo -e "  ${RED}No input available. Run this script from an interactive terminal.${NC}"
        exit 1
    fi

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
