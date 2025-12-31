---
title: changelog
type: note
permalink: changelog
---

## [0.3.0] - 2025-12-16

### Added
- `deploy-key` script for generating CI deploy keys for private repo access

### Changed
- nix-config: Removed determinate input and FlakeHub dependencies
- nix-config: ISO now uses standard NixOS installation-cd-minimal
- nixos-anywhere script: Removed FlakeHub token handling (v1.1.0)

### Fixed
- nix-config/shell.nix: Changed `self` reference to `./.` for git-hooks src
- nix-config/hosts/iso/load-keys.nix: Removed FlakeHub token handling
- All repos now passing `nix flake check`

## [0.2.0] - 2025-12-16

### Changed
- Removed FlakeHub workflows from all repos
- Converted all FlakeHub URLs to GitHub URLs
- nix-config uses local path reference for nix-secrets

### Fixed
- nix-keys: VENTOY_EOF heredoc indentation (shellcheck SC1039)
- nix-keys: Removed nix-syntax hook (SQLite contention)
- nix-secrets: Removed nix-syntax hook
- nix-lib: Fixed systems input URL
- nix-repos: Fixed pog script shellcheck SC2034 warnings

# Changelog

## [0.2.0] - 2025-12-16

### Added
- `scripts/` directory for cross-repo orchestration scripts
- `iso.nix` - ISO build with Ventoy disk and key injection (moved from nix-config)
- `nixos-anywhere.nix` - NixOS deployment with secrets (moved from nix-keys)
- `pog` flake input for building CLI scripts
- `iso` command in shell.nix
- `deploy-nixos` command in shell.nix
- `--config-repo` flag for iso script (defaults to ./nix-config)
- `--keys-repo` flag for both scripts (defaults to ./nix-keys)

### Changed
- Renamed `--build-on-remote` to `--remote-build` (pog 20-char limit)

### Fixed
- nix-keys/flake.nix: Added missing `self` to outputs function

## [0.1.0] - 2025-12-11

### Added
- Initial workspace flake with devshell
- Navigation commands (config, lib, secrets, keys)
- Multi-repo operations (status-all, pull-all, push-all, update-all)
- Validation commands (check, check-all, fmt, show)
- Git hooks integration via git-hooks.nix