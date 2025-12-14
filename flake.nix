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
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      devshell,
      git-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ devshell.overlays.default ];
        };

        hooks = git-hooks.lib.${system}.run {
          src = ./.;
          hooks = import ./githooks.nix { inherit pkgs; };
        };
      in
      {
        checks.pre-commit = hooks;

        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = import ./shell.nix {
          inherit pkgs hooks;
        };
      }
    );
}
