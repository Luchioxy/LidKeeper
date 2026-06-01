#!/bin/bash
# LidKeeper Cross-Platform Installer
# Detects OS and runs the appropriate setup script
# https://github.com/Luchioxy/LidKeeper

set -e

REPO="Luchioxy/LidKeeper"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

# ── Colors ─────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Detect OS ──────────────────────────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

# ── Main ──────────────────────────────────────────────────────────────────────

OS=$(detect_os)

echo ""
echo -e "${CYAN}  LidKeeper Installer${NC}"
echo -e "${CYAN}  Detected OS: $OS${NC}"
echo ""

case $OS in
    windows)
        echo -e "  ${YELLOW}Windows detected. Please use the PowerShell installer:${NC}"
        echo ""
        echo "    irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex"
        echo ""
        ;;
    macos|linux)
        TEMP_DIR=$(mktemp -d)
        # Cleanup temp dir on exit (including SIGINT)
        trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM

        SETUP_URL="$BASE_URL/$OS/setup.sh"
        SETUP_FILE="$TEMP_DIR/setup.sh"

        echo "  Downloading setup script..."
        if curl -sL "$SETUP_URL" -o "$SETUP_FILE"; then
            chmod +x "$SETUP_FILE"
            echo -e "  ${GREEN}Download complete.${NC}"
            echo ""
            bash "$SETUP_FILE"
        else
            echo -e "  ${RED}Failed to download setup script.${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "  ${RED}Unsupported OS: $(uname -s)${NC}"
        echo "  LidKeeper supports macOS, Linux, and Windows."
        exit 1
        ;;
esac
