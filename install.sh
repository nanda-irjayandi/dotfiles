#!/bin/sh

# Handle error
set -eu

echo "Starting dotfiles setup"
echo "Latest revision 20250623"

# Get absolute path of the directory containing this script
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

# XDG Setup
XDG_CONFIG_HOME="${HOME}/.config"
XDG_CACHE_HOME="${HOME}/.cache"
XDG_DATA_HOME="${HOME}/.local/share"
XDG_STATE_HOME="${HOME}/.local/state"

# Dotfiles path
DOTFILES="$HOME/dotfiles"
ZDOTDIR="$HOME/dotfiles/zsh"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
mkdir -p "$HOME/.local/bin"

# Detect Package Manager
detect_package_manager() {
    if command -v brew >/dev/null 2>&1; then echo "brew"
    elif command -v apt >/dev/null 2>&1; then echo "apt"
    elif command -v dnf >/dev/null 2>&1; then echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then echo "pacman"
    else echo "unknown"
    fi
}

# Detect and install Zsh
if ! command -v zsh >/dev/null 2>&1; then
    echo "Zsh not found. Attempting installation..."

    PKG=$(detect_package_manager)

    case "$PKG" in
        brew)
            brew install zsh
            ;;
        apt)
            sudo apt update && sudo apt install -y zsh
            ;;
        dnf)
            sudo dnf install -y zsh
            ;;
        pacman)
            sudo pacman -Sy --noconfirm zsh
            ;;
        *)
            echo "Cannot install Zsh: Unsupported system or missing package manager."
            exit 1
            ;;
    esac
else
    echo "Zsh is already installed."
fi

# Sync submodules
echo "Syncing submodules..."
git submodule sync >/dev/null
git submodule update --init --recursive >/dev/null
git clean -ffd
echo "  ...done"

# Set Zsh as default shell if not already
if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo "Changing default shell to zsh..."
    chsh -s "$(command -v zsh)"
    echo "  ...done"
fi

# Link ~/.zshenv
echo "Linking .zshenv to point to dotfiles ZDOTDIR..."

# Try to read symlink target (works only if ~/.zshenv is a symlink)
LINK_TARGET=$(readlink "$HOME/.zshenv" 2>/dev/null || echo "")

if [ "$LINK_TARGET" = "${SCRIPT_DIR}/zsh/.zshenv" ]; then
    echo "  ...already linked correctly, skipping"
else
    ln -sf "${SCRIPT_DIR}/zsh/.zshenv" "$HOME/.zshenv"
    echo "  ...linked ~/.zshenv -> ${SCRIPT_DIR}/zsh/.zshenv"
fi
