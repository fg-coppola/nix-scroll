{
  description = "Modular Zero-Drift NixOS Configuration";

  inputs = {
    # Core NixOS unstable channel (rolling stable releases tested by Hydra)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Well-engineered systemd & desktop defaults by Numtide
    srvos.url = "github:numtide/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    # Official hardware profiles
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Declarative disk partitioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Secure Boot with custom UKI signing
    lanzaboote.url = "github:nix-community/lanzaboote/v1.2.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager for user environment and dotfiles
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative Flatpak management (auto-uninstalls removed Flatpaks)
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Niri compositor & Wayland plumbing
    niri.url = "github:sodiboo/niri-flake";
    niri.inputs.nixpkgs.follows = "nixpkgs";

    # Dux Shell (formerly DankMaterialShell) stable releases
    dux-shell.url = "github:duxlabs-dev/dux-shell/stable";
    dux-shell.inputs.nixpkgs.follows = "nixpkgs";

    # Chaotic-Nyx for CachyOS kernel, scx_lavd scheduler, and gaming packages
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";

      # Helper function to build any host cleanly without boilerplate
      mkHost = hostName: extraHardwareModules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostName; };
        modules = [
          # Upstream engineered modules
          inputs.srvos.nixosModules.desktop
          inputs.disko.nixosModules.disko
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.chaotic.nixosModules.default
          inputs.niri.nixosModules.niri
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.home-manager.nixosModules.home-manager

          # Our modular architecture
          ./modules/nixos
          ./hosts/${hostName}
        ] ++ extraHardwareModules;
      };
    in
    {
      nixosConfigurations = {
        # 1. Virtual Machine for safe testing
        vm-test = mkHost "vm-test" [
          inputs.srvos.nixosModules.mixins-terminfo
        ];

        # 2. ASUS Vivobook Pro Laptop (Ryzen + RTX + OLED)
        laptop = mkHost "laptop" [
          inputs.nixos-hardware.nixosModules.common-cpu-amd
          inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
          inputs.nixos-hardware.nixosModules.common-gpu-nvidia
          inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
        ];

        # 3. Custom Gaming Desktop (RTX 5070 Ti)
        desktop = mkHost "desktop" [
          inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
          inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
          inputs.nixos-hardware.nixosModules.common-pc-ssd
        ];
      };
    };
}