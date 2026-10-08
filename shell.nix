# shell.nix
# Fallback devshell that keeps only the Nix-built cross-repo tools.
{
  pkgs,
  hooks,
}:

pkgs.devshell.mkShell {
  name = "nix-repos";

  motd = ''
    {202}📦 Nix Repositories Workspace{reset}

    Sibling repositories:
      • nix-config   - NixOS system configurations
      • nix-lib      - Shared library for NixOS/Home Manager
      • nix-secrets  - SOPS-encrypted secrets
      • nix-keys     - SSH key management tools

    The shared workspace devenv provides common CLI tools.
    This fallback shell keeps only the Nix-built deployment helpers.

    $(type -p menu &>/dev/null && menu)
  '';

  packages = [ ];

  commands = [ ];

  devshell.startup = {
    git-hooks.text = hooks.shellHook;
  };
}
