{
  description = "GitHub Actions Runner with Nix tools pre-installed";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in
    {
      # DevShell with all the tools needed for the runner
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nix
              skopeo
              jq
              cosign
              syft
              docker-client
            ];

            shellHook = ''
              echo "ARC Runner Nix Development Shell"
              echo "================================="
              echo "Tools available: nix, skopeo, jq, cosign, syft, docker"
            '';
          };
        }
      );

      # Packages that can be installed
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # Bundle of tools for CI
          ci-tools = pkgs.symlinkJoin {
            name = "arc-runner-ci-tools";
            paths = with pkgs; [
              skopeo
              jq
              cosign
              syft
            ];
          };
        }
      );
    };
}
