{
  description = "A template for Haskell + Nix projects.";

  inputs = {
    haskell-hacknix.url = github:hackworthltd/haskell-hacknix;
    nixpkgs.follows = "haskell-hacknix/nixpkgs";

    hacknix-lib.url = github:hackworthltd/hacknix-lib;
    hacknix-lib.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = github:numtide/flake-utils;

    pre-commit-hooks-nix.url = github:cachix/pre-commit-hooks.nix;
    pre-commit-hooks-nix.flake = false;
  };

  outputs =
    { self
    , nixpkgs
    , hacknix-lib
    , haskell-hacknix
    , flake-utils
    , pre-commit-hooks-nix
    , ...
    }@inputs:
    let
      ## All the systems for which you wish to build the Haskell package.
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
      ];
      forAllSupportedSystems = hacknix-lib.lib.flakes.forAllSystems supportedSystems;

      config = {
        allowUnfree = true;
        allowBroken = true;
      };

      ## Memoize packages for a given system.

      # nixpkgs + the local overlay.
      pkgsFor = forAllSupportedSystems (system:
        import nixpkgs {
          inherit system config;
          overlays = [
            self.overlay
          ];
        }
      );

      # The local Haskell package. This can be configured as a matrix
      # (one package set per compiler/profiling combination) by adding
      # multiple package sets.
      #
      # Note that the Haskell package lives in a subdirectory, but
      # that's easy enough to change, if you don't like this
      # particular organization.
      haskellPackagesFor = forAllSupportedSystems (system:
        let
          pkgs = pkgsFor.${system};
        in
        flake-utils.lib.flattenTree {
          # Add a derivation here for each version of GHC you support
          # (plus variants with profiling enabled, if desired).

          ghc8104 = pkgs.callPackage ./haskell-template {
            compiler-nix-name = "ghc8104";
          };
        }
      );

      # This is used by source-code-checks below.
      preCommitHooksFor = forAllSupportedSystems (system:
        # NB: this is a hack until upstream has Flakes support.
        (import "${pre-commit-hooks-nix}/nix" {
          inherit system nixpkgs;
        }).packages
      );


      ## Some formatting and linting checks.
      source-code-checks = forAllSupportedSystems (system:
        let
          pkgs = pkgsFor.${system};
          preCommitHooks = preCommitHooksFor.${system};
        in
        preCommitHooks.run {
          src = ./.;
          hooks = {
            hlint.enable = true;
            ormolu.enable = true;
            cabal-fmt.enable = true;
            nixpkgs-fmt.enable = true;
          };

          # Override the default nix-pre-commit-hooks tools with the
          # versions from haskell-hacknix. You don't have to do this,
          # but if you do, you'll get the same versions as the ones
          # provided by `devShell`.
          tools = {
            inherit (pkgs.haskell-hacknix.haskell-tools) hlint ormolu cabal-fmt;
            inherit (pkgs) nixpkgs-fmt;
          };
        }
      );

      ## A development shell (for `nix develop`).
      #
      # Note that there's just one shell (per supported system), so we
      # need to choose a particular GHC version here. It's easy enough
      # to change, though.
      devShell = forAllSupportedSystems
        (system:
          let
            haskellPackages = haskellPackagesFor.${system};
          in
          haskellPackages."ghc8104/shell"
        );

    in
    {
      overlay = hacknix-lib.lib.overlays.combine [
        haskell-hacknix.overlay
        (final: prev:
          let
            haskellPackages = final.callPackage ./haskell-template {
              compiler-nix-name = "ghc8104";
            };
          in
          {
            # If your Haskell package contains any executables, add
            # them here. Otherwise, you can probably leave this
            # attrset empty, unless you want to add the local Haskell
            # package set to the overlay, for some reason.

            haskell-template = haskellPackages.exe;
          }
        )
      ];

      packages = forAllSupportedSystems
        (system:
          let
            pkgs = pkgsFor.${system};
          in
          {
            # As above for the overlay, generally speaking, you'll
            # probably only want to include executables here. If you
            # want to build a package with no executables (e.g., a
            # Haskell library), you can just use the `checks`
            # attribute.

            inherit (pkgs) haskell-template;
          }
        );

      inherit devShell;

      # Evaluating this Flake output will build the local Haskell
      # package and then run its tests (called "checks" in haskell.nix
      # projects).
      #
      # Note that we can't evaluate `source-code-checks` here because
      # it's not compatible with `nix flake`. See:
      # 
      # https://github.com/cachix/pre-commit-hooks.nix/pull/67
      #
      # (`source-code-checks` does work fine in `hydraJobs` because
      # Hydra doesn't use `nix flake` to evaluate it.)
      checks = forAllSupportedSystems
        (system: {
          # Add one attribute here for each GHC you want to use.

          ghc8104 = self.hydraJobs.haskell-template.${system}."ghc8104/checks/haskell-template/haskell-template-test";
        });

      hydraJobs = {
        build = self.packages;

        # When Hydra evaluates this attribute, it will build all the
        # derivations exported by the local Haskell package (shell,
        # executable, libs, etc.), for all supported systems, for each
        # GHC + profiling combination that you define in the
        # `haskellPackagesFor` attrset above.
        haskell-template = forAllSupportedSystems
          (system:
            let
              haskellPackages = haskellPackagesFor.${system};
            in
            flake-utils.lib.flattenTree haskellPackages
          );

        # This only needs to be built for one platform.
        source-code-checks = source-code-checks.x86_64-linux;

        # It's handy to have Hydra build the shells, so that they're cached.
        shell = devShell;
      };

      ciJobs = hacknix-lib.lib.flakes.recurseIntoHydraJobs self.hydraJobs;
    };
}
