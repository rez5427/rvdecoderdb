{ lib
, stdenv
, makeWrapper
, writeShellApplication

, mill
, mill-ivy-fetcher
, riscv-opcodes-src
, ivy-gather
, add-determinism-hook
}:
let
  ivyCache = ivy-gather ./sailcodegen-jvm-mill-lock.nix;
in
stdenv.mkDerivation rec {
  name = "sailcodegen-jvm-jar";

  src = with lib.fileset;
    toSource {
      root = ./../..;
      fileset = unions [
        ../../build.mill
        ../../common.mill
        ../../sailcodegen
        ../../rvdecoderdb
      ];
    };

  nativeBuildInputs = [
    makeWrapper
    add-determinism-hook
  ];

  propagatedBuildInputs = [
    mill
  ];

  buildInputs = [ ivyCache ];

  passthru = {
    inherit ivyCache;
    bump = writeShellApplication {
      name = "bump-sailcodegen-jvm-jar-lock";
      runtimeInputs = [ mill mill-ivy-fetcher ];
      text = ''
        mif run -p ${src} -o ./nix/sailcodegen-jvm-jar/sailcodegen-jvm-mill-lock.nix
      '';
    };
  };

  buildPhase = ''
    runHook preBuild

    cp -rT ${riscv-opcodes-src} sailcodegen/jvm/riscv-opcodes
    mill -i 'sailcodegen.jvm.assembly'

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/java

    mv out/sailcodegen/jvm/assembly.dest/out.jar $out/share/java/sailcodegen.jar

    mkdir -p $out/bin
    makeWrapper ${mill.jre}/bin/java $out/bin/sailcodegen \
      --add-flags "-jar $out/share/java/sailcodegen.jar"

    runHook postInstall
  '';

  meta.mainProgram = "mif";
}

