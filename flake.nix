{
  description = "rvdecoderdb";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    chisel-nix.url = "github:chipsalliance/chisel-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, chisel-nix, flake-utils }@inputs:
    let
      overlay = import ./overlay.nix;
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ chisel-nix.overlays.mill-flows overlay ]; };
          commonDeps = with pkgs; [
            mill
            espresso
          ];

        in
        {
          legacyPackages = pkgs;
          devShells = {
            default = pkgs.mkShell {
              buildInputs = commonDeps;
            };
          };
        }
      )
    // { inherit inputs; overlays.default = overlay; };
}
