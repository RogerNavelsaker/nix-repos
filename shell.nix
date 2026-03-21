# shell.nix
# Central devshell provides workspace commands for sibling Nix repos
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

    $(type -p menu &>/dev/null && menu)
  '';

  packages = [ ];

  commands = [
    # Navigation Category
    {
      category = "navigation";
      name = "config";
      help = "Enter nix-config devshell";
      command = ''
        cd ../nix-config && nix develop
      '';
    }
    {
      category = "navigation";
      name = "lib";
      help = "Enter nix-lib directory";
      command = ''
        cd ../nix-lib && nix develop
      '';
    }
    {
      category = "navigation";
      name = "secrets";
      help = "Enter nix-secrets devshell";
      command = ''
        cd ../nix-secrets && nix develop
      '';
    }
    {
      category = "navigation";
      name = "keys";
      help = "Enter nix-keys devshell";
      command = ''
        cd ../nix-keys && nix develop
      '';
    }

    # Multi-repo Operations
    {
      category = "multi-repo";
      name = "status-all";
      help = "Show git status for all sibling repos";
      command = ''
        for repo in ../nix-config ../nix-lib ../nix-secrets ../nix-keys; do
          if [ -d "$repo/.git" ]; then
            echo -e "\n{202}=== $(basename "$repo") ==={reset}"
            git -C "$repo" status --short
          fi
        done
      '';
    }
    {
      category = "multi-repo";
      name = "pull-all";
      help = "Pull latest changes for all sibling repos";
      command = ''
        for repo in ../nix-config ../nix-lib ../nix-secrets ../nix-keys; do
          if [ -d "$repo/.git" ]; then
            echo -e "\n{202}=== Pulling $(basename "$repo") ==={reset}"
            git -C "$repo" pull --rebase
          fi
        done
      '';
    }
    {
      category = "multi-repo";
      name = "push-all";
      help = "Push all sibling repos with changes";
      command = ''
        for repo in ../nix-config ../nix-lib ../nix-secrets ../nix-keys; do
          if [ -d "$repo/.git" ]; then
            ahead=$(git -C "$repo" rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
            if [ "$ahead" -gt 0 ]; then
              echo -e "\n{202}=== Pushing $(basename "$repo") ($ahead commits ahead) ==={reset}"
              git -C "$repo" push
            fi
          fi
        done
      '';
    }
    {
      category = "multi-repo";
      name = "update-all";
      help = "Update flake inputs for all sibling repos";
      command = ''
        for repo in ../nix-config ../nix-lib ../nix-secrets ../nix-keys; do
          if [ -f "$repo/flake.nix" ]; then
            echo -e "\n{202}=== Updating $(basename "$repo") ==={reset}"
            nix flake update --flake "$repo"
          fi
        done
      '';
    }

    # Validation Category
    {
      category = "validation";
      name = "check";
      help = "Run flake checks for this workspace";
      command = "nix flake check";
    }
    {
      category = "validation";
      name = "check-all";
      help = "Run flake checks for all sibling repos";
      command = ''
        for repo in ../nix-config ../nix-lib ../nix-secrets ../nix-keys; do
          if [ -f "$repo/flake.nix" ]; then
            echo -e "\n{202}=== Checking $(basename "$repo") ==={reset}"
            nix flake check "$repo" || true
          fi
        done
      '';
    }
    {
      category = "validation";
      name = "fmt";
      help = "Format all nix files in workspace";
      command = "nixfmt .";
    }
    {
      category = "validation";
      name = "show";
      help = "Display flake outputs structure";
      command = "nix flake show";
    }

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
