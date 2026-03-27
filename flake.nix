{
  description = "GoClaw Multi-agent AI gateway";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    flake-parts,
    self,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      inherit systems;
      flake = {
        nixosModules = {
          default = flake-parts.lib.importApply ./nix/module.nix {
            localFlake = self;
            inherit (flake-parts.lib) withSystem;
          };
        };
      };
      perSystem = {
        pkgs,
        system,
        ...
      }: let
        goclaw = pkgs.buildGo126Module {
          name = "goclaw";
          src = pkgs.lib.cleanSource ./.;
          vendorHash = null;
        };

        goclaw-web = pkgs.stdenv.mkDerivation (finalAttrs: {
          pname = "goclaw-web";
          version = "0.1.0";
          src = ./ui/web;
          nativeBuildInputs = with pkgs; [
            nodejs
            pnpmConfigHook
            pnpm
          ];
          pnpmDeps = pkgs.fetchPnpmDeps {
            inherit (finalAttrs) pname version src;
            fetcherVersion = 3;
            hash = "sha256-4GykWtBlPY0vxUnHrf+UsU7krdMlxLWNF8qjEo3ZrlQ=";
          };
          buildPhase = ''
            runHook preBuild
            pnpm build
            cp -r dist/ $out
            runHook postBuild
          '';
        });
      in let
        goclaw-package =
          pkgs.runCommand "goclaw"
          {
            buildInputs = [pkgs.makeWrapper];
          }
          ''
            mkdir -p $out/bin $out/migrations $out/share
            cp ${goclaw}/bin/goclaw $out/bin/goclaw
            cp -r ${./migrations}/* $out/migrations/
            ln -s ${goclaw-web} $out/share/goclaw-web
            wrapProgram $out/bin/goclaw --set GOCLAW_MIGRATIONS_DIR "$out/migrations"
          '';
      in {
        packages.default = goclaw-package;
        packages.goclaw-web = goclaw-web;
        checks.goclaw-test = import ./nix/test.nix {
          inherit pkgs;
          goclaw = goclaw-package;
        };
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            goclaw
            goclaw-web
          ];
        };
      };
    };
}
