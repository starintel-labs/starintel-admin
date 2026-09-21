{
  description = "Portable StarIntel operator administration CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      packages = forAllSystems (pkgs:
        let
          starintel-admin = pkgs.writeShellApplication {
            name = "starintel-admin";
            runtimeInputs = with pkgs; [
              bash
              coreutils
              curl
              jq
              openssl
            ];
            text = builtins.readFile ./bin/starintel-admin;
          };
        in {
          default = starintel-admin;
          inherit starintel-admin;
        });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.system}.default}/bin/starintel-admin";
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
