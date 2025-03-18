{ stdenv
, ocamlPackages
, fetchFromGitHub
, lib
, fetchMillDeps
, mill
, z3
}:

let
  rvdecoderdbtestSrc = with lib.fileset; toSource {
    fileset = unions [
      ../build.mill
      ../common.mill
      ../rvdecoderdbtest
      ../rvdecoderdb
    ];
    root = ../.;
  };
  rvdecoderdbtestDeps = fetchMillDeps {
    name = "rvdecoderdbtest";
    src = rvdecoderdbtestSrc;
    millDepsHash = "sha256-j6ixFkxLsm8ihDLFkkJDePVuS2yVFmX3B1gOUVguCHQ=";
  };
  rvdecoderdbDeps = fetchMillDeps {
    name = "rvdecoderdb";
    src = rvdecoderdbtestSrc;
    millDepsHash = "sha256-j6ixFkxLsm8ihDLFkkJDePVuS2yVFmX3B1gOUVguCHQ=";
  };
in

let
  ocamlPackages' = ocamlPackages.overrideScope (finalScope: prevScope: {
    sail = prevScope.sail.overrideAttrs rec {
      version = "0.18";
      src = fetchFromGitHub {
        owner = "rems-project";
        repo = "sail";
        rev = version;
        hash = "sha256-QvVK7KeAvJ/RfJXXYo6xEGEk5iOmVsZbvzW28MHRFic=";
      };

      buildInputs = [ finalScope.menhirLib ];
    };
  });
  riscv-opcodes = {
    pname = "riscv-opcodes";
    version = "8899b32f218c85bf2559fa95f226bc2533316802";
    src = fetchFromGitHub {
      owner = "riscv";
      repo = "riscv-opcodes";
      rev = "8899b32f218c85bf2559fa95f226bc2533316802";
      fetchSubmodules = false;
      sha256 = "sha256-7CV/T8gnE7+ZPfYbn38Zx8fYUosTc8bt93wk5nmxu2c=";
    };
    date = "2025-02-14";
  };
in


stdenv.mkDerivation {
  name = "sail";
  src = rvdecoderdbtestSrc;

  nativeBuildInputs = with ocamlPackages'; [
    ocamlbuild
    findlib
    ocaml
    z3
    sail
    mill
    rvdecoderdbDeps.setupHook
  ];

  buildInputs = with riscv-opcodes; [
    rvdecoderdbtestDeps.setupHook
  ];

  buildPhase = ''
    cp -r ${riscv-opcodes.src} rvdecoderdbtest/jvm/riscv-opcodes
    export SAIL_FLAGS="--require-version 0.18 --strict-var -dno_cast"
    mill -i 'rvdecoderdbtest.jvm.runMain' sailCodeGen rv64i

    sail $SAIL_FLAGS -O -Oconstant_fold -memo_z3 -c \
      -c_include ../c/lib.h \
      -c_no_main \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/lib/prelude.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/rv_xlen.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/capi.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/lib/scattered.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/arch/ArchPrelude.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/arch/ArchStatesPrivEnable.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/arch/ArchStateCsrBF.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/arch/ArchStates.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/arch/ArchStatesRW.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/arch/ArchStatesInit.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/rv_core.sail \
      ./rvdecoderdbtest/jvm/src/sail/rvcore/sailexpose.sail \
      -o ./rvdecoderdbtest/jvm/src/sail/rvcore/rv_model

    cc -g $C_FLAGS ./rvdecoderdbtest/jvm/src/sail/rvcore/rv_model.c $C_SRCS $SAIL_LIB_DIR/*.c $C_LIBS -o $out/bin/rv
    ./rv
  '';
}