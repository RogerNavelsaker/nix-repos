# shell.nix
# Fallback devshell that keeps only the Nix-built cross-repo tools.
{
  pkgs,
  hooks,
  scripts,
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

    Flox + direnv owns navigation, status, update, and validation commands.
    This fallback shell keeps only the Nix-built deployment helpers.

    $(type -p menu &>/dev/null && menu)
  '';

  packages = [ ];

  commands = [
    # Cross-repo Operations (orchestrate multiple repos)
    {
      category = "cross-repo";
      name = "iso";
      help = "ISO management: iso <build|run|stop|restart|status|ssh|log> (--help for details)";
      command = ''
        ${scripts.iso}/bin/iso "$@"
      '';
    }
    {
      category = "cross-repo";
      name = "deploy-nixos";
      help = "Deploy NixOS via nixos-anywhere (--help for details)";
      command = ''
        ${scripts.nixos-anywhere}/bin/nixos-anywhere "$@"
      '';
    }
    {
      category = "cross-repo";
      name = "deploy-key";
      help = "Generate deploy keys for CI: deploy-key <generate|show|instructions>";
      command = ''
        ${scripts.deploy-key}/bin/deploy-key "$@"
      '';
    }
    {
      category = "cross-repo";
      name = "ventoy";
      help = "Create Ventoy disk with ISO and encrypted pass store: ventoy <create|info>";
      command = ''
        ${scripts.ventoy}/bin/ventoy "$@"
      '';
    }
  ];

  devshell.startup = {
    git-hooks.text = hooks.shellHook;
  };
}
