---
title: active-context
type: note
permalink: active-context
---

# Active Context

## Recent Events (Sliding Window)
- [2025-12-31] Created Home Manager modules in users/features/default/
- [2025-12-31] Updated users/rona/aio to use shared modules
- [2025-12-31] Updated users/rona/nanoserver to use shared modules
- [2025-12-31] Added homeConfigurations and apps.home-switch to flake.nix
- [2025-12-31] Created migrate-to-hm.sh and verify-hm.sh scripts
- [2025-12-31] Fixed Home Manager options for HM 25.05+ (git.settings, delta, ssh)
- [2025-12-31] All flake checks passing
## Current Focus
FlakeHub/Determinate removal complete. All repositories now use standard NixOS tooling with GitHub URLs. Deploy key tooling added for CI access to private nix-secrets repo.
## Active Decisions

- Cross-repo scripts live in nix-repos/scripts/
- Repo-local scripts stay in their respective repos
- Command names: `iso` and `deploy-nixos` (renamed from nixos-anywhere due to pog 20-char limit)

- [2025-12-16] Removed FlakeHub workflows from all repos (nix-lib, nix-secrets, nix-keys, nix-config)
- [2025-12-16] Converted all FlakeHub URLs to GitHub URLs across all repos
- [2025-12-16] Fixed nix-keys: heredoc indentation (SC1039), removed nix-syntax hook
- [2025-12-16] Fixed nix-secrets: removed nix-syntax hook (SQLite contention in CI)
- [2025-12-16] Fixed nix-lib: systems input now uses github:nix-systems/default-linux
- [2025-12-16] nix-config: uses local path for nix-secrets (private repo), has pre-existing determinate-nixd issue