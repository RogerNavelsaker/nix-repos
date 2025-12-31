---
title: system-patterns
type: note
permalink: system-patterns
---

# System Patterns

## Architecture

```
nix-repos/                    # Workspace (orchestration layer)
├── flake.nix                 # Meta-flake with pog, devshell, git-hooks
├── shell.nix                 # Cross-repo commands + navigation
├── scripts/                  # Cross-repo orchestration scripts
│   ├── iso.nix               # nix-config ISO + nix-keys injection
│   └── nixos-anywhere.nix    # Deploy with secrets
├── nix-config/               # NixOS configurations (nested repo)
├── nix-keys/                 # SSH key management (nested repo)
├── nix-secrets/              # SOPS secrets (nested repo)
└── nix-lib/                  # Shared library (nested repo)
```

## Design Decisions

### Script Ownership

| Type | Location | Rationale |
|------|----------|-----------|
| Cross-repo | nix-repos/scripts/ | Orchestrates multiple repos |
| Repo-local | <repo>/scripts/ | Domain-specific to single repo |

### Cross-repo Script Criteria

A script is cross-repo if it:
- References multiple nested repositories
- Passes data between repos (e.g., keys → ISO)
- Would break if a repo is moved independently

### Command Naming

- Prefer short names: `iso`, `deploy-nixos`
- pog library has 20-char limit for flag display (`-x, --flag-name`)
- Use `-r, --remote-build` not `-r, --build-on-remote` (21 chars)

## Technical Constraints

- **pog**: Flag names with short options must fit in 20 chars total
- **devshell**: Known upstream warning about derivation context (#238)
- **Nested flakes**: `nix flake check` evaluates subflakes, may trigger auth
