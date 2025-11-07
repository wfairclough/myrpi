#!/bin/bash

# myrpi - Raspberry Pi Development Environment Setup Script
# This script installs and configures common development tools
# Usage: sudo ./init.sh setup

set -e          # Exit on error
set -u          # Exit on undefined variable
set -o pipefail # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation directories
INSTALL_DIR="/usr/local"
CONFIG_DIR="$HOME/.config/myrpi"
TEMP_DIR="/tmp/rpi-setup-$$"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run with sudo"
    exit 1
  fi
}

# Get the actual user (not root when using sudo)
get_actual_user() {
  if [[ -n "${SUDO_USER:-}" ]]; then
    echo "$SUDO_USER"
  else
    echo "$USER"
  fi
}

# Check if command exists
check_command() {
  command -v "$1" &>/dev/null
}

# Install apt package if not already installed
install_apt_package() {
  local package=$1
  if check_command "$package"; then
    log_info "$package is already installed, skipping"
  else
    log_info "Installing $package via apt..."
    apt-get install -y "$package"
  fi
}

# Download and verify file with sha256
download_and_verify() {
  local url=$1
  local output=$2
  local expected_sha256=$3

  log_info "Downloading from $url..."
  curl -fsSL "$url" -o "$output"

  if [[ -n "$expected_sha256" ]]; then
    log_info "Verifying sha256 checksum..."
    echo "$expected_sha256  $output" | sha256sum -c - || {
      log_error "Checksum verification failed!"
      return 1
    }
  fi
}

# Install from GitHub release (tar.gz)
install_github_release() {
  local name=$1
  local url=$2
  local sha256=$3
  local extract_dir=${4:-$name} # Optional: directory name in tar

  if check_command "$name"; then
    log_info "$name is already installed, skipping"
    return 0
  fi

  log_info "Installing $name from GitHub release..."
  local tarball="$TEMP_DIR/${name}.tar.gz"

  download_and_verify "$url" "$tarball" "$sha256"

  log_info "Extracting $name..."
  tar -xzf "$tarball" -C "$TEMP_DIR"

  # Find the extracted directory and move contents to /usr/local
  local extracted=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "${extract_dir}*" | head -n 1)
  if [[ -z "$extracted" ]]; then
    log_error "Failed to find extracted directory for $name"
    return 1
  fi

  # Copy to /usr/local
  cp -r "$extracted"/* "$INSTALL_DIR/"

  log_info "$name installed successfully"
}

# Install from curl script
install_curl_script() {
  local name=$1
  local command=$2

  if check_command "$name"; then
    log_info "$name is already installed, skipping"
    return 0
  fi

  log_info "Installing $name via curl script..."
  eval "$command"
}

# System update
system_update() {
  log_info "Updating system packages..."
  apt-get update
  apt-get upgrade -y
}

# Install apt packages
install_apt_packages() {
  log_info "Installing apt packages..."

  local packages=(
    git
    jq
    yq
    htop
    zoxide
    ripgrep
    tmux
    lazygit
    httpie
  )

  for package in "${packages[@]}"; do
    install_apt_package "$package"
  done
}

# Install GitHub CLI (gh)
install_gh() {
  if check_command "gh"; then
    log_info "gh is already installed, skipping"
    return 0
  fi

  log_info "Installing GitHub CLI (gh)..."

  # Add GitHub CLI repository
  log_info "Adding GitHub CLI apt repository..."

  # Install dependencies
  apt-get install -y curl gnupg

  # Add GPG key
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

  # Add repository
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  # Update and install
  apt-get update
  apt-get install -y gh

  log_info "gh installed successfully"
}

# Install neovim
install_neovim() {
  local nvim_url="https://github.com/neovim/neovim/releases/download/v0.11.5/nvim-linux-arm64.tar.gz"
  local nvim_sha256="ea4f9a31b11cc1477ff014aebb7b207684e7280f94ffa97abdab6cacd9b98519"

  if check_command "nvim"; then
    log_info "neovim is already installed, skipping"
    return 0
  fi

  log_info "Installing neovim..."
  local tarball="$TEMP_DIR/nvim.tar.gz"

  download_and_verify "$nvim_url" "$tarball" "$nvim_sha256"

  log_info "Extracting neovim..."
  tar -xzf "$tarball" -C "$TEMP_DIR"

  # Move to /usr/local
  cp -r "$TEMP_DIR/nvim-linux-arm64/"* "$INSTALL_DIR/"

  log_info "neovim installed successfully"
}

# Install lazyvim
install_lazyvim() {
  local actual_user=$(get_actual_user)
  local user_home=$(eval echo "~$actual_user")
  local nvim_config="$user_home/.config/nvim"

  if [[ -d "$nvim_config" ]]; then
    log_info "Neovim config already exists at $nvim_config, skipping lazyvim installation"
    return 0
  fi

  log_info "Installing LazyVim starter config..."

  # Clone as the actual user, not root
  sudo -u "$actual_user" git clone https://github.com/LazyVim/starter "$nvim_config"
  sudo -u "$actual_user" rm -rf "$nvim_config/.git"

  log_info "LazyVim installed successfully"
}

# Install bat
install_bat() {
  local bat_url="https://github.com/sharkdp/bat/releases/download/v0.26.0/bat-v0.26.0-aarch64-unknown-linux-musl.tar.gz"
  local bat_sha256="6ee11bd8a520c514e230669156d9298f0dd2b5afc788c0952a4b14fcec51eaee"

  if check_command "bat"; then
    log_info "bat is already installed, skipping"
    return 0
  fi

  log_info "Installing bat..."
  local tarball="$TEMP_DIR/bat.tar.gz"

  download_and_verify "$bat_url" "$tarball" "$bat_sha256"

  log_info "Extracting bat..."
  tar -xzf "$tarball" -C "$TEMP_DIR"

  # Find bat binary and copy to /usr/local/bin
  local extracted=$(find "$TEMP_DIR" -type d -name "bat-*" | head -n 1)
  cp "$extracted/bat" "$INSTALL_DIR/bin/"

  log_info "bat installed successfully"
}

# Install atuin
install_atuin() {
  local actual_user=$(get_actual_user)
  local user_home=$(eval echo "~$actual_user")

  if check_command "atuin"; then
    log_info "atuin is already installed, skipping"
    return 0
  fi

  log_info "Installing atuin..."
  sudo -u "$actual_user" bash -c 'bash <(curl --proto "=https" --tlsv1.2 -sSf https://setup.atuin.sh)'

  # Add cargo bin to PATH for this script (atuin installs to ~/.cargo/bin)
  export PATH="$user_home/.cargo/bin:$PATH"
  log_info "Added atuin to PATH for current session"
}

# Install uv
install_uv() {
  local actual_user=$(get_actual_user)
  local user_home=$(eval echo "~$actual_user")

  if check_command "uv"; then
    log_info "uv is already installed, skipping"
    return 0
  fi

  log_info "Installing astral uv..."
  sudo -u "$actual_user" bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'

  # Add uv to PATH for this script
  export PATH="$user_home/.local/bin:$PATH"
  log_info "Added uv to PATH for current session"
}

# Install Python with uv
install_python() {
  local actual_user=$(get_actual_user)
  local user_home=$(eval echo "~$actual_user")
  local python_version="3.14"

  # Ensure uv is in PATH
  export PATH="$user_home/.local/bin:$PATH"

  # Check if uv is installed
  if ! check_command "uv"; then
    log_error "uv is not installed. Please install uv first."
    return 1
  fi

  log_info "Installing Python $python_version with uv..."

  # Install Python using uv (runs as actual user)
  if sudo -u "$actual_user" bash -c "export PATH=\"\$HOME/.local/bin:\$PATH\" && uv python list" | grep -q "$python_version"; then
    log_info "Python $python_version already installed"
  else
    log_info "Installing Python $python_version (this may take a few minutes)..."
    sudo -u "$actual_user" bash -c "export PATH=\"\$HOME/.local/bin:\$PATH\" && uv python install $python_version"
  fi

  log_info "Python $python_version installed successfully"
}

# Install asdf
install_asdf() {
  local asdf_url="https://github.com/asdf-vm/asdf/releases/download/v0.18.0/asdf-v0.18.0-linux-arm64.tar.gz"
  local asdf_sha256="1749b89039e4af51b549aa0919812fd68722c1a26a90eaf84db0b46a39f557a9"
  local actual_user=$(get_actual_user)
  local user_home=$(eval echo "~$actual_user")
  local asdf_dir="$user_home/.asdf"

  if [[ -d "$asdf_dir" ]]; then
    log_info "asdf is already installed, skipping"
    return 0
  fi

  log_info "Installing asdf..."
  local tarball="$TEMP_DIR/asdf.tar.gz"

  download_and_verify "$asdf_url" "$tarball" "$asdf_sha256"

  log_info "Extracting asdf..."
  sudo -u "$actual_user" mkdir -p "$asdf_dir"
  sudo -u "$actual_user" tar -xzf "$tarball" -C "$asdf_dir" --strip-components=1

  log_info "asdf installed successfully"
}

# Install fzf
install_fzf() {
  local fzf_url="https://github.com/junegunn/fzf/releases/download/v0.66.1/fzf-0.66.1-linux_armv7.tar.gz"
  local fzf_sha256="88ac3b2b34d57de430df468f0518e7d3c3ea9edbd01b4ef764c9a68207f24c39"

  if check_command "fzf"; then
    log_info "fzf is already installed, skipping"
    return 0
  fi

  log_info "Installing fzf..."
  local tarball="$TEMP_DIR/fzf.tar.gz"

  download_and_verify "$fzf_url" "$tarball" "$fzf_sha256"

  log_info "Extracting fzf..."
  tar -xzf "$tarball" -C "$INSTALL_DIR/bin/"

  log_info "fzf installed successfully"
}

# Install Node.js with asdf
install_nodejs() {
  local actual_user=$(get_actual_user)
  local user_home=$(eval echo "~$actual_user")
  local asdf_dir="$user_home/.asdf"
  local nodejs_version="24.11.0"

  # Check if asdf is installed
  if [[ ! -d "$asdf_dir" ]]; then
    log_error "asdf is not installed. Please install asdf first."
    return 1
  fi

  log_info "Setting up Node.js with asdf..."

  # Source asdf for this script
  export ASDF_DIR="$asdf_dir"
  export ASDF_DATA_DIR="$asdf_dir"
  source "$asdf_dir/asdf.sh"

  # Add nodejs plugin if not already added
  if ! sudo -u "$actual_user" bash -c "source $asdf_dir/asdf.sh && asdf plugin list" | grep -q "nodejs"; then
    log_info "Adding asdf nodejs plugin..."
    sudo -u "$actual_user" bash -c "source $asdf_dir/asdf.sh && asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git"
  else
    log_info "asdf nodejs plugin already installed"
  fi

  # Check if Node.js version is already installed
  if sudo -u "$actual_user" bash -c "source $asdf_dir/asdf.sh && asdf list nodejs 2>/dev/null" | grep -q "$nodejs_version"; then
    log_info "Node.js $nodejs_version already installed"
  else
    log_info "Installing Node.js $nodejs_version (this may take a few minutes)..."
    sudo -u "$actual_user" bash -c "source $asdf_dir/asdf.sh && asdf install nodejs $nodejs_version"
  fi

  # Set global Node.js version
  log_info "Setting global Node.js version to $nodejs_version..."
  sudo -u "$actual_user" bash -c "source $asdf_dir/asdf.sh && asdf global nodejs $nodejs_version"

  log_info "Node.js $nodejs_version installed and set as global version"
}

# Setup configuration
setup_config() {
  local actual_user=$(get_actual_user)
  local user_home=$(eval echo "~$actual_user")
  local config_dir="$user_home/.config/myrpi"
  local bashrc="$user_home/.bashrc"

  log_info "Setting up configuration..."

  # Create config directory
  sudo -u "$actual_user" mkdir -p "$config_dir"

  # Copy env file with checksum comparison
  if [[ -f "$SCRIPT_DIR/config/env" ]]; then
    local source_env="$SCRIPT_DIR/config/env"
    local target_env="$config_dir/env"

    # If target exists, compare checksums
    if [[ -f "$target_env" ]]; then
      local source_sha=$(sha256sum "$source_env" | awk '{print $1}')
      local target_sha=$(sha256sum "$target_env" | awk '{print $1}')

      if [[ "$source_sha" != "$target_sha" ]]; then
        log_warn "Config file has changed, updating $target_env"
        sudo -u "$actual_user" cp "$source_env" "$target_env"
        log_info "Updated config/env with new version from repository"
      else
        log_info "Config file is up to date, skipping"
      fi
    else
      # Target doesn't exist, copy it
      sudo -u "$actual_user" cp "$source_env" "$target_env"
      log_info "Copied config/env to $config_dir/env"
    fi
  else
    log_warn "config/env not found in repository, skipping"
  fi

  # Update .bashrc to source env file
  local source_line="source ~/.config/myrpi/env"
  if ! grep -q "$source_line" "$bashrc" 2>/dev/null; then
    sudo -u "$actual_user" bash -c "echo '' >> $bashrc"
    sudo -u "$actual_user" bash -c "echo '# Source myrpi environment' >> $bashrc"
    sudo -u "$actual_user" bash -c "echo '$source_line' >> $bashrc"
    log_info "Added source line to .bashrc"
  else
    log_info ".bashrc already sources myrpi env, skipping"
  fi
}

# Configure git aliases
setup_git_aliases() {
  local actual_user=$(get_actual_user)

  log_info "Setting up git aliases..."

  # Define aliases as "name|command" pairs
  local aliases=(
    "s|status"
    "co|checkout"
    "publish|push origin main"
    "branch-name|rev-parse --abbrev-ref HEAD"
    "pull-current|!git pull origin \$(git rev-parse --abbrev-ref HEAD)"
    "lol|log --pretty=format:'%C(yellow)%h %Cred%ad %Cblue%<(15,trunc)%an%Cgreen%d %Creset%s' --date=short"
    "fzf-branch|!git branch | fzf"
    "fzf-co|!f() { git checkout \$(git branch | fzf); }; f"
    "l|log"
    "com|commit"
    "br|branch -vv"
    "unstage|reset HEAD"
    "sha|rev-parse HEAD"
    "shortsha|rev-parse --short HEAD"
  )

  for alias_pair in "${aliases[@]}"; do
    local alias_name="${alias_pair%%|*}"
    local alias_cmd="${alias_pair#*|}"

    # Check if alias already exists
    if sudo -u "$actual_user" git config --global --get "alias.$alias_name" &>/dev/null; then
      log_info "Git alias '$alias_name' already exists, skipping"
    else
      sudo -u "$actual_user" git config --global "alias.$alias_name" "$alias_cmd"
      log_info "Added git alias: $alias_name"
    fi
  done

  log_info "Git aliases configured successfully"
}

# Display welcome banner
show_welcome_banner() {
  echo ""
  echo -e "${GREEN}"
  cat <<"EOF"
 __          __  _                            _
 \ \        / / | |                          | |
  \ \  /\  / /__| | ___ ___  _ __ ___   ___  | |_ ___
   \ \/  \/ / _ \ |/ __/ _ \| '_ ` _ \ / _ \ | __/ _ \
    \  /\  /  __/ | (_| (_) | | | | | |  __/ | || (_) |
     \/  \/ \___|_|\___\___/|_| |_| |_|\___|  \__\___/

                              _ _
                             (_) |
  _ __ ___  _   _ _ __  _ __  _| |
 | '_ ` _ \| | | | '__/| '_ \| | |
 | | | | | | |_| | |   | |_) | |_|
 |_| |_| |_|\__, |_|   | .__/|_(_)
             __/ |     | |
            |___/      |_|

EOF
  echo -e "${NC}"
  echo -e "${YELLOW}Raspberry Pi Development Environment Setup${NC}"
  echo ""
}

# Main setup function
setup() {
  show_welcome_banner
  log_info "Starting Raspberry Pi setup..."

  # Get user info for PATH updates
  local actual_user=$(get_actual_user)
  local user_home=$(eval echo "~$actual_user")

  # Update PATH to include all installation directories
  export PATH="/usr/local/bin:$user_home/.local/bin:$user_home/.cargo/bin:$PATH"
  log_info "Updated PATH for installation session"

  # Create temp directory
  mkdir -p "$TEMP_DIR"

  # Ensure cleanup on exit
  trap "rm -rf $TEMP_DIR" EXIT

  # Run all installation steps
  system_update
  install_apt_packages
  install_gh
  install_neovim
  install_lazyvim
  install_bat
  install_atuin
  install_uv
  install_python
  install_asdf
  install_nodejs
  install_fzf
  setup_config
  setup_git_aliases

  log_info "Setup completed successfully!"
  log_info "Please restart your shell or run: source ~/.bashrc"
}

# Main entry point
main() {
  check_root

  case "${1:-}" in
  setup)
    setup
    ;;
  *)
    echo "Usage: sudo ./init.sh setup"
    exit 1
    ;;
  esac
}

main "$@"
