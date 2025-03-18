final: prev:
{
  mill = prev.mill.overrideAttrs {
    version = "unstable-0.12.5-173-15dded";
    src = final.fetchurl {
      url = "https://github.com/com-lihaoyi/mill/releases/download/0.12.5/0.12.5-173-15dded-assembly";
      hash = "sha256-xP59tONOu0CG5Gce4ru+st5KUH7Wcd10d/pQdELjSJM=";
    };
  };

  espresso = final.callPackage ./nix/espresso.nix { };

  rvdecoderdb-jvm = final.callPackage ./nix/rvdecoderdb-jvm.nix { };

  sail = final.callPackage ./nix/sailcodegen.nix { };
}
