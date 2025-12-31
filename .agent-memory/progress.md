---
title: progress
type: note
permalink: progress
---

# Progress

## Current Status
All repositories passing `nix flake check`:
- **nix-repos**: ✅ workspace flake with cross-repo scripts
- **nix-lib**: ✅ GitHub URLs, no FlakeHub dependency
- **nix-secrets**: ✅ GitHub URLs, pre-commit hooks fixed
- **nix-keys**: ✅ GitHub URLs, heredoc/shellcheck issues fixed
- **nix-config**: ✅ FlakeHub and determinate-nixd removed, standard NixOS ISO
## What Works
- **Workspace shell** - devshell with navigation, multi-repo ops, validation commands
- **Cross-repo scripts**:
  - `iso` - Build NixOS ISO with Ventoy disk and key injection from nix-keys
  - `deploy-nixos` - Deploy NixOS via nixos-anywhere with secrets from nix-keys
  - `deploy-key` - Generate and manage deploy keys for CI access to private repos
- **Multi-repo commands** - status-all, pull-all, push-all, update-all, check-all
- **Git hooks** - Pre-commit formatting via git-hooks.nix
## Known Issues
1. **nix-secrets private access**: Using `git+file:../nix-secrets` for local dev; CI needs SSH deploy key configured (use `deploy-key` command)
2. **devshell warning**: "Using builtins.derivation... without proper context" - cosmetic, non-blocking
## Next Steps

- [ ] Consider adding more cross-repo orchestration scripts as needs arise
- [ ] Document the workspace architecture in README
