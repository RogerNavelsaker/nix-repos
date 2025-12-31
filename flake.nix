# flake.nix
{
  description = "Nix repositories workspace - meta flake for nested repos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pog = {
      url = "github:jpetrucciani/pog";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      devshell,
      git-hooks,
      pog,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ devshell.overlays.default ];
          config = {
            allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "ventoy" # Required for Ventoy disk creation scripts
              ];
            permittedInsecurePackages = [
              "ventoy-1.1.07" # Ventoy marked insecure but required for disk creation
            ];
          };
        };

        hooks = git-hooks.lib.${system}.run {
          src = self;
          hooks = import ./githooks.nix { inherit pkgs; };
        };

        scripts = import ./scripts {
          inherit pkgs;
          inherit (pog.packages.${system}) pog;
        };
      in
      {
        checks.pre-commit = hooks;

        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = import ./shell.nix {
          inherit pkgs hooks scripts;
        };
      }
    );
}
