{ haskell-hacknix
, haskell-nix
, recurseIntoAttrs
, compiler-nix-name
}:
let
  haskellPackages = haskell-nix.cabalProject {
    name = "haskell-template";
    src = ../.;
    subdir = "haskell-template";
    inherit compiler-nix-name;
  };

  shell = haskell-hacknix.shellFor haskellPackages { };

  localPackages = haskell-nix.haskellLib.selectLocalPackages haskellPackages;
  tests = haskell-hacknix.lib.collectTests' localPackages;
  checks = haskell-nix.haskellLib.collectChecks' localPackages;

  exe = haskellPackages.haskell-template.components.exes.haskell-template;

in
recurseIntoAttrs
{
  inherit exe shell tests checks;
}
