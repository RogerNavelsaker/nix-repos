# nix-repos

Meta-project for the Nix-focused repositories under `RogerNavelsaker/*`.

This repository is the shared workspace entrypoint for the Nix layer: development shell, Flox environment, shared hooks, workspace file, and helper scripts that support the rest of the Nix repos. It complements, rather than replaces, the individual repositories listed below.

## Repositories

| Repository | Focus |
| --- | --- |
| [nix-config](https://github.com/RogerNavelsaker/nix-config) | System and user configuration |
| [nix-lib](https://github.com/RogerNavelsaker/nix-lib) | Shared Nix helpers, modules, and library code |
| [nix-repos](https://github.com/RogerNavelsaker/nix-repos) | Workspace flake, dev shell, hooks, and repo-level scripts |
| [nix-keys](https://github.com/RogerNavelsaker/nix-keys) | Yubikey-backed encrypted key material |
| [nix-secrets](https://github.com/RogerNavelsaker/nix-secrets) | SOPS-encrypted secrets repository |

## What Lives Here

- `.flox/env/manifest.toml` and `.envrc` for the preferred Flox + `direnv` shell
- `flake.nix` and `shell.nix` for the fallback Nix-built environment
- `githooks.nix` for repo-wide checks
- `scripts/` for deployment and system utility tasks
- `nix-repos.code-workspace` for the multi-repo editor workspace

## Intended Use

- Clone this repo as `~/Repositories/@nix-repos` and keep the underlying repos as ignored child directories inside `@nix-repos/`
- Use Flox + `direnv` as the default shell entrypoint
- Use Flox for navigation, workspace status, update, and validation commands
- Keep `shell.nix` only for the Nix-built deployment helpers
- Use it as the top-level workspace when working across multiple nested Nix repositories
- Keep reusable logic in `nix-lib` and system-specific configuration in `nix-config`
- Bootstrap missing child repos with `./scripts/bootstrap`
- Inspect workspace state with `./scripts/status` or `status-all`
- Submodules are intentionally not used

## Related Meta Projects

- [nixpkgs](https://github.com/RogerNavelsaker/nixpkgs) for packaged CLI wrappers
- [runtime-intel](https://github.com/RogerNavelsaker/runtime-intel) for code intelligence and runtime integration tooling
