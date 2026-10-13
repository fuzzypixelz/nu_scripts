{
  description = "A place to share Nushell scripts with each other";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forEachSystem (system: {
        nu-hooks = nixpkgs.legacyPackages.${system}.stdenv.mkDerivation {
          name = "nu-hooks";
          version = "0.2.0";
          src = ./.;
          dontBuild = true;
          installPhase = ''
            mkdir -p "$out/share/nu-hooks"
            cp -r "$src/nu-hooks" "$out/share/"
          '';
        };
      });
      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
