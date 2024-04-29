{
  description = "firefoxUserChrome";

  inputs = {
    nixpkgs.url     = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url    = "github:numtide/devshell";
  };

  outputs = { self, ... }@inputs: let etcFirefoxChromePath = "firefox/chrome"; in
    (inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devshell.flakeModule
      ];
      systems   = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      perSystem = { pkgs, lib, system, ... }: rec {
        packages.default  =
        let
          firefoxUserPrefs = [
            { name  = "toolkit.legacyUserProfileCustomizations.stylesheets";
              value = "true";
            }
            { name  = "ui.key.menuAccessKeyFocuses";
              value = "false";
            }
          ];
          setupFirefoxProfile = pkgs.writeShellScriptBin "setupFirefoxProfile" (''
            if [ $# = 0 ]; then
              echo firefox profile path is required
              exit 1
            fi

            cd $1
            pwd
            ls
            echo
            read -p "Press enter to continue: "

            ln -f -s /etc/${etcFirefoxChromePath}
            rm -f user.js
          '' + lib.concatMapStringsSep "\n"
                 (up: ''echo "user_pref(\"${up.name}\", ${up.value});" >> user.js'')
                 firefoxUserPrefs);
        in setupFirefoxProfile;

        devshells.default = {
          packages = [ packages.default ];
        };
      };
    }) // {
      name         = "firefoxUserChrome";
      nixosModules = rec {
        addpkg = { pkgs, ... }: {
          nixpkgs.config = {
            packageOverrides = oldpkgs: let newpkgs = oldpkgs.pkgs; in {
              "${self.name}" = self.packages."${pkgs.system}".default;
            };
          };
        };

        install = { pkgs, ... }: (addpkg { inherit pkgs; }) // {
          environment = {
            systemPackages                = [ pkgs."${self.name}" ];
            etc."${etcFirefoxChromePath}" = {
              source = ./.;
            };
          };
        };
      };
    };
}
