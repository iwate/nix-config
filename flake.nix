{
  description = "NixOS configuration with Noctalia";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    srtcam = {
      url = "github:iwate/srtcam";
      flake = false;
    };

    genzo = {
      url = "git+https://github.com/iwate/genzo.git?submodules=1";
      flake = false;
    };
  };
  
  nixConfig = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
  };  

  outputs = inputs@{ self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };

    genzoPackage = pkgs.callPackage ./pkgs/genzo/package.nix {
      inherit (inputs) genzo;
    };
  in {
    packages.${system} = {
      genzo = genzoPackage;
      default = genzoPackage;
    };

    apps.${system} = {
      genzo = {
        type = "app";
        program = "${genzoPackage}/bin/genzo";
      };
      default = {
        type = "app";
        program = "${genzoPackage}/bin/genzo";
      };
    };

    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = system;
      specialArgs = { inherit inputs; };
      modules = [
        # ... other modules
        ./hosts/laptop/configuration.nix
        inputs.noctalia.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.iwate = import ./home-manager/home.nix;
        }
        {
          imports = [inputs.silentSDDM.nixosModules.default];
          programs.silentSDDM = {
            enable = true;
            theme = "default";
            settings = {
            };
          };
        }
      ];
    };
  };
}
