{ config, inputs, pkgs, ... }:

{
  imports = [
    ./disko-btrfs.nix
    ./core.nix
    ./hardware.nix
    ./roles.nix
  ];

  # Integrate Home Manager into the NixOS rebuild cycle
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      mySystem = config.mySystem;
    };
    users.${config.mySystem.username} = import ../home;
  };
}