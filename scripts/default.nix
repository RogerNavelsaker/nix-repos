# scripts/default.nix
{ pkgs, pog }:
let
  call = f: import f { inherit pkgs pog; };
in
{
  iso = call ./iso.nix;
  nixos-anywhere = call ./nixos-anywhere.nix;
}
