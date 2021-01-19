# haskell-template

This repo contains a Nix Flake for building Haskell Cabal projects
using [nixpkgs](https://github.com/NixOS/nixpkgs) and
[haskell.nix](https://github.com/input-output-hk/haskell.nix).

To adapt this Nix Flake to your own projects, for the most part you
just need to:

1. rename the `haskell-template` subdirectory;

2. put your Cabal project source in the renamed subdirectory; and

3. grep for `"haskell-template"`, replacing any occurrences of that
string with the name of your Haskell project.

For the full documentation, please see the included `flake.nix` file.

## License

The project's default license is BSD-3, but you may re-license this
project using any other license, at your discretion.
