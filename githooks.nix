# githooks.nix
{ pkgs }:

{
  nixfmt-rfc-style = {
    enable = true;
    name = "nixfmt";
    description = "Format Nix files with nixfmt-rfc-style";
    entry = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
    types = [ "nix" ];
  };

  deadnix = {
    enable = true;
    name = "deadnix";
    description = "Find dead Nix code";
    entry = "${pkgs.deadnix}/bin/deadnix --fail";
    types = [ "nix" ];
  };

  statix = {
    enable = true;
    name = "statix";
    description = "Lints and suggestions for Nix code";
    entry = "${pkgs.statix}/bin/statix check";
    types = [ "nix" ];
    pass_filenames = false;
  };
}
