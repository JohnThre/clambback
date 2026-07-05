{
  description = "clambback package";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "clambback";
            version = "1.0.0-alpha.2";
            src = self;

            nativeBuildInputs = [ pkgs.cmake ];
            buildInputs = [
              pkgs.boost
              pkgs.openssl
            ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.CoreFoundation
              pkgs.darwin.apple_sdk.frameworks.Security
            ];

            cmakeFlags = [
              "-DENABLE_MYSQL=OFF"
              "-DSYSTEMD_SERVICE=OFF"
            ];

            meta = with pkgs.lib; {
              description = "C++ network service with TLS transport support";
              homepage = "https://github.com/JohnThre/clambback";
              license = licenses.gpl3Plus;
              maintainers = [ ];
              mainProgram = "clambback";
              platforms = platforms.unix;
            };
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/clambback";
        };
      });

      checks = forAllSystems (system: {
        default = self.packages.${system}.default;
      });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.boost
              pkgs.cmake
              pkgs.openssl
            ];
          };
        });
    };
}
