# scripts/default.nix
{ pkgs, pog }:
let
  call = f: import f { inherit pkgs pog; };
in
{
  iso = call ./iso.nix;
  ventoy = call ./ventoy.nix;
  nixos-anywhere = call ./nixos-anywhere.nix;
  deploy-key = call ./deploy-key.nix;
}
