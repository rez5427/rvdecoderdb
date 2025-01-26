{ lib
, fetchMillDeps
, publishMillJar
}:
let
  rvdecoderdbSrc = with lib.fileset; toSource {
    fileset = unions [
      ../build.mill
      ../common.mill
      ../rvdecoderdb
    ];
    root = ../.;
  };
  rvdecoderdbDeps = fetchMillDeps {
    name = "rvdecoderdb";
    src = rvdecoderdbSrc;
    millDepsHash = "sha256-j6ixFkxLsm8ihDLFkkJDePVuS2yVFmX3B1gOUVguCHQ=";
  };
in
publishMillJar {
  name = "rvdecoderdb";

  src = rvdecoderdbSrc;

  buildInputs = [
    rvdecoderdbDeps.setupHook
  ];

  publishTargets = [
    "rvdecoderdb.jvm"
  ];

  passthru = {
    inherit rvdecoderdbSrc;
  };
}
