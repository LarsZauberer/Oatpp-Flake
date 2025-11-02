{
  description = "A flake to install all the important parts for oatpp and its modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      postInstallFix = nested: ''
        # Copy libraries and headers to standard locations
        cp -r $out/lib/oatpp-1.3.0/* $out/lib/
        cp -r $out/include/oatpp-1.3.0/${nested}/* $out/include/

        # Fix cmake config files - oatpp installs in versioned subdirectories
        # but CMake expects standard locations
        for file in $out/lib/cmake/oatpp-1.3.0/*.cmake; do
          # Fix hardcoded store paths in cmake config
          sed -i 's|//nix/store/[^/]*/lib/oatpp-1\.3\.0/|"/lib/"|g' "$file"
          # Fix absolute store paths containing version directories
          sed -i 's|$out/lib/oatpp-1\.3\.0|$out/lib|g' "$file"
          sed -i 's|$out/include/oatpp-1\.3\.0/oatpp|$out/include|g' "$file"
          # Fix relative versioned paths
          sed -i 's|lib/oatpp-1\.3\.0|lib|g' "$file"
          sed -i 's|include/oatpp-1\.3\.0/oatpp|include|g' "$file"
          sed -i 's|include/oatpp-1\.3\.0/|include/|g' "$file"
          # Clean up any double paths or slashes
          sed -i 's|$out$out|$out|g' "$file"
          sed -i 's|//|/|g' "$file"
        done
      '';

      my_oatpp = pkgs.oatpp.overrideAttrs (old: {
        postInstall = postInstallFix "oatpp";
      });

      buildInputs = with pkgs; [
        gcc
        gdb
        cmake
      ];
    in {
      packages.default = self.packages.${system}.oatpp;
      packages.oatpp = my_oatpp;
      packages.swagger = pkgs.stdenv.mkDerivation {
        pname = "oatpp-swagger";
        version = "1.3.1";

        src = pkgs.fetchFromGitHub {
          owner = "oatpp";
          repo = "oatpp-swagger";
          tag = "1.3.1";

          hash = "sha256-TuRtxjuorhimEjN3rXJjrxDpX1dUmboXOIUCmQFiOUA=";
        };

        nativeBuildInputs = buildInputs ++ [self.packages.${system}.oatpp];

        cmakeFlags = [
          "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
        ];

        postInstall = postInstallFix "oatpp-swagger";
      };
      devShells.default = pkgs.mkShell {
        name = "devShell";

        buildInputs = buildInputs;
      };
    });
}
