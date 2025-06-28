#!/usr/bin/env bash

set -euo pipefail

export SCRIPT_DIR
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

# Default XDG paths
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"

log_info() { echo "[INFO] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# Detect Package Manager
detect_package_manager() {
    local managers=(
        "brew:brew"
        "apt:apt-get"
        "dnf:dnf"
        "pacman:pacman"
        "yum:yum"
        "zypper:zypper"
    )
    
    for manager in "${managers[@]}"; do
        local cmd="${manager#*:}"
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "${manager%:*}"
            return 0
        fi
    done
    
    echo "unknown"
    return 1
}

install_zsh() {
    if command -v zsh >/dev/null 2>&1; then
        log_info "Zsh is already installed: $(zsh --version)"
        return 0
    fi
    
    log_info "Zsh not found. Attempting installation..."
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        brew)
            log_info "Installing via Homebrew..."
            brew install zsh || {
                log_error "Failed to install zsh via brew"
                return 1
            }
            ;;
        apt)
            log_info "Installing via apt..."
            sudo apt update && sudo apt install -y zsh || {
                log_error "Failed to install zsh via apt"
                return 1
            }
            ;;
        dnf)
            log_info "Installing via dnf..."
            sudo dnf install -y zsh || {
                log_error "Failed to install zsh via dnf"
                return 1
            }
            ;;
        pacman)
            log_info "Installing via pacman..."
            sudo pacman -Sy --noconfirm zsh || {
                log_error "Failed to install zsh via pacman"
                return 1
            }
            ;;
        yum)
            log_info "Installing via yum..."
            sudo yum install -y zsh || {
                log_error "Failed to install zsh via yum"
                return 1
            }
            ;;
        zypper)
            log_info "Installing via zypper..."
            sudo zypper install -y zsh || {
                log_error "Failed to install zsh via zypper"
                return 1
            }
            ;;
        *)
            log_error "Unsupported package manager or architecture"
            return 1
            ;;
    esac
    
    log_info "Completed zsh installation"
}

setup_zshenv() {
    local target_zshenv="${SCRIPT_DIR}/zsh/.zshenv"
    local home_zshenv="${HOME}/.zshenv"
    
    log_info "Checking ZDOTDIR configuration..."
    
    # Check if ZDOTDIR is properly set
    if [[ -n "${ZDOTDIR:-}" && "${ZDOTDIR}" == "${SCRIPT_DIR}/zsh" ]]; then
        log_info "ZDOTDIR is correctly set, skipping .zshenv symlink"
        return 0
    fi

    if [[ ! -f "$target_zshenv" ]]; then
        log_error ".zshenv not found at $target_zshenv"
        return 1
    fi
    
    # Backup existing .zshenv if it's not a symlink to our target
    if [[ -e "$home_zshenv" && ! -L "$home_zshenv" ]]; then
        local backup="${home_zshenv}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warn "Backing up existing .zshenv to $backup"
        mv "$home_zshenv" "$backup"
    elif [[ -L "$home_zshenv" && "$(readlink "$home_zshenv")" != "$target_zshenv" ]]; then
        log_warn "Removing existing .zshenv symlink (points to different target)"
        rm "$home_zshenv"
    fi
    

    
    # Create symlink
    log_info "Creating .zshenv symlink"
    ln -sf "$target_zshenv" "$home_zshenv"
    log_info "Completed zshenv setup"
}

setup_submodules() {
    log_info "Setting up submodules..."

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_warn "Not in a git repository, skipping submodule setup"
        return 0
    fi

    git submodule sync --recursive >/dev/null 2>&1 || {
        log_error "Failed to sync git submodules"
        return 1
    }

    git submodule update --init --recursive >/dev/null 2>&1 || {
        log_error "Failed to update git submodules"
        return 1
    }

    log_info "Cleaning submodules..."
    git submodule foreach --recursive 'git clean -ffd' >/dev/null || {
        log_warn "Failed to clean some sub-modules (non-critical)"
    }

    log_info "Completed submodule setup"
}

main() {
    log_info "Starting dotfiles installation..."
    log_info "Script directory: $SCRIPT_DIR"
    
    # Install Zsh
    install_zsh || {
        log_error "Failed to install Zsh"
        exit 1
    }
    
    # Setup zshenv
    setup_zshenv || {
        log_error "Failed to setup zshenv"
        exit 1
    }
    
    # Setup submodules
    setup_submodules || {
        log_error "Failed to setup submodules"
        exit 1
    }
    
    # Check if Zsh is available before switching
    if ! command -v zsh >/dev/null 2>&1; then
        log_error "Zsh is not available after installation"
        exit 1
    fi
    
    log_info "Switching to Zsh for plugin compilation..."
    
    # Switch to Zsh with proper error handling and scope isolation
    exec zsh -c '
        # Strict mode for Zsh
        set -eo pipefail
        
        # Get script directory from environment
        SCRIPT_DIR="${1:-}"
        if [[ -z "$SCRIPT_DIR" ]]; then
            print "ERROR: SCRIPT_DIR not provided" >&2
            exit 1
        fi
        
        print "Starting Zsh execution in: $SCRIPT_DIR"
        
        compile_plugins() {
            local plugin_file
            local compiled_count=0
            
            print "Compiling Zsh plugins..."
            
            # Load zrecompile function
            autoload -Uz zrecompile
            
            # Check if plugins directory exists
            if [[ ! -d "${SCRIPT_DIR}/zsh/plugins" ]]; then
                print "WARN: No plugins directory found, skipping compilation" >&2
                return 0
            fi
            
            # Compile plugin files with error handling
            for plugin_file in "${SCRIPT_DIR}"/zsh/plugins/**/*.zsh{-theme,}(#qN.); do
                if [[ -r "$plugin_file" ]]; then
                    if zrecompile -pq "$plugin_file" 2>/dev/null; then
                        ((compiled_count++))
                    else
                        print "WARN: Failed to compile $plugin_file" >&2
                    fi
                fi
            done
            
            print "Compiled $compiled_count plugin files"
        }
        
        # Compile configuration files
        compile_configs() {
            local config_file
            local compiled_count=0
            
            print "Compiling Zsh configuration files..."
            
            autoload -Uz zrecompile
            
            # Compile main config files
            for config_file in "${SCRIPT_DIR}"/zsh/.z{shenv,profile,shrc}(#qN.); do
                if [[ -r "$config_file" ]]; then
                    if zrecompile -pq "$config_file" 2>/dev/null; then
                        ((compiled_count++))
                    else
                        print "WARN: Failed to compile $config_file" >&2
                    fi
                fi
            done
            
            # Compile files in rc.d and env.d directories
            for config_file in "${SCRIPT_DIR}"/zsh/{rc,env}.d/*(.N); do
                if [[ -r "$config_file" ]]; then
                    if zrecompile -pq "$config_file" 2>/dev/null; then
                        ((compiled_count++))
                    else
                        print "WARN: Failed to compile $config_file" >&2
                    fi
                fi
            done
            
            print "Compiled $compiled_count configuration files"
        }
        
        # Run compilation functions
        compile_plugins
        compile_configs
        
        print "Zsh setup completed successfully!"
        print "You may need to restart your shell or run: source ~/.zshenv"
    ' -- "$SCRIPT_DIR"
}

# Run main function
main "$@"