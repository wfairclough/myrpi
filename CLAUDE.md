# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository (myrpi) contains Raspberry Pi setup scripts written in bash. The scripts are intended to configure the Raspberry Pi with common development tools and create a productive development environment.

## Repository Structure

The repository is organized to support Raspberry Pi development and experimentation with a focus on automation and ease of use.

## Development Environment

This project targets Raspberry Pi hardware. When developing scripts:
- Assume scripts may need to run on Raspberry Pi OS (Debian-based)
- Assume Raspberry Pi 4 Model B is the intended target
- Consider ARM 64 architecture compatibility when suggesting dependencies
- Be mindful of GPIO pin access and hardware-specific requirements

## Repository Structure

```
myrpi/
├── init.sh           # Main setup script
├── config/
│   └── env          # Shell environment configuration
├── CLAUDE.md        # This file
└── README.md        # Project documentation
```

## Setup Process

### Running the Setup Script

To configure a Raspberry Pi with all development tools:

```bash
sudo ./init.sh setup
```

**Important**: The script MUST be run with sudo as it installs system-wide packages.

### What the Script Does

1. Updates system packages (`apt update && apt upgrade`)
2. Installs apt packages (git, jq, yq, htop, zoxide, ripgrep, tmux, lazygit, httpie)
3. Installs GitHub CLI (gh) via official apt repository
4. Downloads and installs GitHub releases with SHA256 verification:
   - neovim (v0.11.5)
   - bat (v0.26.0)
   - asdf (v0.18.0)
   - fzf (v0.66.1)
5. Runs curl-based installers for atuin and astral uv
6. Installs Node.js v24.11.0 via asdf and sets it as the global version
7. Sets up LazyVim configuration for neovim
8. Copies `config/env` to `~/.config/myrpi/env`
9. Modifies `~/.bashrc` to source the environment file
10. Configures global git aliases for common operations

### Script Features

- **Idempotent**: Safe to run multiple times; skips already-installed tools
- **Error handling**: Stops on any error (`set -e`)
- **SHA256 verification**: Verifies checksums for downloaded binaries
- **User preservation**: Runs installations as the actual user (not root) when appropriate
- **Config file management**: Compares SHA256 checksums of config files and automatically updates if changed

## Extending the Setup Script

### Adding New Tools

The script is designed for easy extension. To add a new tool:

1. **For apt packages**: Add to the `packages` array in `install_apt_packages()`

2. **For GitHub releases**: Call `install_github_release` in the `setup()` function:
   ```bash
   install_github_release "tool-name" "https://github.com/.../tool.tar.gz" "sha256hash" "extracted-dir-name"
   ```

3. **For curl scripts**: Call `install_curl_script` in the `setup()` function:
   ```bash
   install_curl_script "tool-name" "bash <(curl -sSL https://...)"
   ```

4. **For custom installs**: Create a new `install_toolname()` function and call it in `setup()`

### Environment Configuration

The `config/env` file contains:
- PATH modifications for all installed tools
- Tool-specific configurations (bat theme, fzf settings)
- Useful aliases (cat→bat, cd→zoxide)
- Custom shell functions (mkcd, extract, note)
- Shell prompt with git branch display
- History settings and shell options

To add new configurations, edit `config/env` and they'll be applied on next shell restart.

### Git Aliases

The script automatically configures these global git aliases:

- `git s` → `git status`
- `git co` → `git checkout`
- `git publish` → `git push origin main`
- `git branch-name` → Get current branch name
- `git pull-current` → Pull from origin for current branch
- `git lol` → Pretty formatted log with colors
- `git fzf-branch` → List branches with fzf
- `git fzf-co` → Checkout branch using fzf
- `git l` → `git log`
- `git com` → `git commit`
- `git br` → `git branch -vv` (verbose branch list)
- `git unstage` → `git reset HEAD`
- `git sha` → Get full commit SHA
- `git shortsha` → Get short commit SHA

## Git Workflow

- Main branch: `main`
