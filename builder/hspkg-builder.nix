{ pkgs, buildPackages, stdenv, lib, haskellLib, ghc, buildGHC, fetchurl, runCommand, comp-builder, setup-builder, makeSetupConfigFiles }:


{ flags
, package
, components
, cabal-generator

, name
, sha256
, src
, revision
, revisionSha256
, patches

, shellHook

, ...
}@config:

let
  cabalFile = if revision == null || revision == 0 then null else
    fetchurl {
      name = "${name}-${toString revision}.cabal";
      url = "https://hackage.haskell.org/package/${name}/revision/${toString revision}.cabal";
      sha256 = revisionSha256;
    };

  defaultSetupSrc = builtins.toFile "Setup.hs" ''
    import Distribution.Simple
    main = defaultMain
  '';

  defaultConfig = makeSetupConfigFiles {
    inherit (package) identifier;
    inherit (config) flags;
    fullName = "${name}-setup";
    component = {
      depends = [];
      libs = [];
      frameworks = [];
      doExactConfig = false;
    };
  };
  defaultSetup =
    buildPackages.runCommand
      "default-Setup"
      { nativeBuildInputs = [buildGHC];
        CABAL_CONFIG = defaultConfig + /cabal.config;
      }
      ''
        cat ${defaultSetupSrc} > Setup.hs
        mkdir -p $out/bin
        ${buildGHC.targetPrefix}ghc Setup.hs --make -o $out/bin/Setup
      '';

  setup = if package.buildType == "Simple"
    then defaultSetup
    else setup-builder {
      setup-depends = package.setup-depends;
      inherit (config) preUnpack postUnpack;
      inherit package name src flags;
    };

  buildComp = componentId: component: comp-builder {
    inherit componentId component package name src flags setup cabalFile cabal-generator patches revision
            shellHook
            ;
  };

in {
  components = haskellLib.applyComponents buildComp config;
  inherit (package) identifier;
  inherit setup cabalFile;
  isHaskell = true;
}
