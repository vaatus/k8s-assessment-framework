#!/bin/bash
#
# kubeafr CLI Installation Script
# Installs the unified CLI tool for the Kubernetes Assessment Framework
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "╦╔═╦ ╦╔╗ ╔═╗╔═╗╔═╗╦═╗"
    echo "╠╩╗║ ║╠╩╗║╣ ╠═╣╠╣ ╠╦╝"
    echo "╩ ╩╚═╝╚═╝╚═╝╩ ╩╚  ╩╚═"
    echo -e "${NC}${MAGENTA}Kubernetes Assessment Framework${NC}"
    echo ""
}

print_banner

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "kubeafr CLI Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLI_SOURCE="${SCRIPT_DIR}/kubeafr"

# Check if CLI source exists
if [ ! -f "$CLI_SOURCE" ]; then
    print_error "CLI source not found: $CLI_SOURCE"
    exit 1
fi

print_info "CLI source: $CLI_SOURCE"

# Check Python 3
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required but not installed"
    exit 1
fi
print_success "Python 3 found: $(python3 --version)"

# Check for required Python packages
echo ""
print_info "Checking Python dependencies..."

MISSING_DEPS=()

if ! python3 -c "import yaml" 2>/dev/null; then
    MISSING_DEPS+=("PyYAML")
fi

if ! python3 -c "import jwt" 2>/dev/null; then
    MISSING_DEPS+=("PyJWT")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    print_warning "Missing Python packages: ${MISSING_DEPS[*]}"
    echo ""
    read -p "Install missing packages? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing packages..."
        pip3 install "${MISSING_DEPS[@]}"
        print_success "Packages installed"
    else
        print_error "Installation cancelled"
        exit 1
    fi
else
    print_success "All dependencies satisfied"
fi

# Determine installation location
echo ""
print_info "Choose installation location:"
echo "  1) /usr/local/bin (system-wide, requires sudo)"
echo "  2) ~/.local/bin (user only)"
echo "  3) Custom path"
echo ""

read -p "Selection [1-3]: " CHOICE

case $CHOICE in
    1)
        INSTALL_DIR="/usr/local/bin"
        NEEDS_SUDO=true
        ;;
    2)
        INSTALL_DIR="$HOME/.local/bin"
        NEEDS_SUDO=false
        # Create directory if it doesn't exist
        mkdir -p "$INSTALL_DIR"
        ;;
    3)
        read -p "Enter custom path: " CUSTOM_PATH
        INSTALL_DIR="$CUSTOM_PATH"
        NEEDS_SUDO=false
        mkdir -p "$INSTALL_DIR"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

INSTALL_PATH="${INSTALL_DIR}/kubeafr"

# Check if already installed
if [ -f "$INSTALL_PATH" ]; then
    print_warning "kubeafr already installed at $INSTALL_PATH"
    read -p "Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
fi

# Install CLI
echo ""
print_info "Installing kubeafr to $INSTALL_DIR..."

if [ "$NEEDS_SUDO" = true ]; then
    sudo cp "$CLI_SOURCE" "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH"
else
    cp "$CLI_SOURCE" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"
fi

print_success "CLI installed: $INSTALL_PATH"

# Check if installation directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    print_warning "Installation directory not in PATH"
    echo ""
    echo "Add to your PATH by adding this to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    echo ""
fi

# Install bash completion (optional)
echo ""
read -p "Install bash completion? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    COMPLETION_DIR=""

    if [ -d "/etc/bash_completion.d" ]; then
        COMPLETION_DIR="/etc/bash_completion.d"
        NEEDS_SUDO=true
    elif [ -d "$HOME/.bash_completion.d" ]; then
        COMPLETION_DIR="$HOME/.bash_completion.d"
        NEEDS_SUDO=false
    else
        mkdir -p "$HOME/.bash_completion.d"
        COMPLETION_DIR="$HOME/.bash_completion.d"
        NEEDS_SUDO=false
    fi

    COMPLETION_FILE="${COMPLETION_DIR}/kubeafr"

    # Generate completion script
    cat > /tmp/kubeafr-completion << 'EOF'
# Bash completion for kubeafr

_kubeafr_completions() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # All available commands
    instructor_commands="deploy upload-specs view-results decode-token reupload-template"
    student_commands="eval submit status tasks"
    utility_commands="validate-spec list-tasks check-prereqs"
    help_commands="help version"

    commands="$instructor_commands $student_commands $utility_commands $help_commands"

    # Complete command names
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    # Command-specific completions
    case "${COMP_WORDS[1]}" in
        validate-spec|eval|submit)
            # Complete with task IDs
            local tasks=$(ls -d ~/k8s-workspace/tasks/task-* 2>/dev/null | xargs -n 1 basename 2>/dev/null || ls -d tasks/task-* 2>/dev/null | xargs -n 1 basename 2>/dev/null || echo "task-01 task-02 task-03 task-04 task-05")
            COMPREPLY=( $(compgen -W "$tasks" -- "$cur") )
            return 0
            ;;
        decode-token)
            # Complete with files
            COMPREPLY=( $(compgen -f -- "$cur") )
            return 0
            ;;
        view-results)
            # Complete with student IDs (if available)
            COMPREPLY=( $(compgen -f -- "$cur") )
            return 0
            ;;
    esac
}

complete -F _kubeafr_completions kubeafr
EOF

    if [ "$NEEDS_SUDO" = true ]; then
        sudo mv /tmp/kubeafr-completion "$COMPLETION_FILE"
    else
        mv /tmp/kubeafr-completion "$COMPLETION_FILE"
    fi

    print_success "Bash completion installed: $COMPLETION_FILE"

    if [ "$COMPLETION_DIR" = "$HOME/.bash_completion.d" ]; then
        echo ""
        echo "Add to your ~/.bashrc:"
        echo ""
        echo "  for f in ~/.bash_completion.d/*; do source \$f; done"
        echo ""
    fi
fi

# Test installation
echo ""
print_info "Testing installation..."

if command -v kubeafr &> /dev/null; then
    VERSION=$(kubeafr version 2>/dev/null | grep -i version | head -1 || echo "unknown")
    print_success "Installation successful!"
    print_info "$VERSION"
else
    print_warning "kubeafr command not found in PATH"
    print_info "You may need to restart your shell or add $INSTALL_DIR to your PATH"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BOLD}Quick Start:${NC}"
echo ""
echo -e "  ${CYAN}Instructor Commands:${NC}"
echo "    kubeafr deploy              # Deploy infrastructure"
echo "    kubeafr upload-specs        # Upload task specifications"
echo "    kubeafr view-results        # View student results"
echo ""
echo -e "  ${MAGENTA}Student Commands:${NC}"
echo "    kubeafr eval task-01        # Request evaluation"
echo "    kubeafr submit task-01      # Submit final solution"
echo "    kubeafr status              # Check environment"
echo "    kubeafr tasks               # List available tasks"
echo ""
echo -e "  ${BLUE}Help:${NC}"
echo "    kubeafr help                # Show help"
echo "    kubeafr version             # Show version"
echo ""
