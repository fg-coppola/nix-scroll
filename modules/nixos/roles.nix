{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.mySystem.roles;
  user = config.mySystem.username;
in
{
  options.mySystem.roles = {
    desktop.enable = lib.mkEnableOption "Niri + Dux Shell desktop environment";
    dev.enable = lib.mkEnableOption "Development stack (Podman, Libvirt/KVM, nix-ld, envfs)";
    gaming.enable = lib.mkEnableOption "Gaming optimizations (CachyOS kernel, scx_lavd, Steam)";
  };

  config = lib.mkMerge [
    # 1. DESKTOP ROLE: Niri + Dux Shell (formerly DMS) + Fonts
    (lib.mkIf cfg.desktop.enable {
      programs.niri.enable = true;

      # Native Dux Shell module: automatically sets up systemd user service (Wants=dms.service)
      programs.dms-shell = {
        enable = true;
        package = inputs.dux-shell.packages.${pkgs.system}.default;
        systemd.enable = true;
      };

      # Fast filesystem search integration for Dux launcher
      programs.dsearch.enable = true;

      # Dux Greeter (greetd) synced with user theme and fingerprint PAM support
      services.displayManager.dms-greeter = {
        enable = true;
        compositor.name = "niri";
        configHome = "/home/${user}";
      };
      security.pam.services.greetd.fprintAuth = config.mySystem.hardware.asusVivobook.enable;

      # Keyring, Seahorse, and KDE Connect (automatically opens firewall ports)
      services.gnome.gnome-keyring.enable = true;
      programs.seahorse.enable = true;
      programs.kdeconnect.enable = true;

      # Ensure niri.service explicitly wants dms.service (replaces 10-dms-wants.conf)
      systemd.user.services.niri.wants = [ "dms.service" ];

      # Nerd Fonts and Google Fonts
      fonts.packages = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.hack
        nerd-fonts.sauce-code-pro
        nerd-fonts.terminus
        nerd-fonts.jetbrains-mono
        nerd-fonts.symbols-only
        roboto
        open-sans
        inter
        material-symbols
      ];
    })

    # 2. DEVELOPMENT ROLE: Podman Rootless Socket, KVM, and FHS Compatibility
    (lib.mkIf cfg.dev.enable {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
      systemd.user.sockets.podman.wantedBy = [ "sockets.target" ];
      environment.sessionVariables = {
        DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
      };

      # QEMU/KVM & Virt-Manager
      virtualisation.libvirtd.enable = true;
      programs.virt-manager.enable = true;

      # Transparent FHS compatibility so mise, uv, and prebuilt binaries work out-of-the-box
      services.envfs.enable = true;
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          stdenv.cc.cc
          zlib
          zstd
          openssl
          curl
          glib
          libGL
          libxkbcommon
          wayland
          vulkan-loader
        ];
      };
    })

    # 3. GAMING ROLE: CachyOS Kernel, LAVD Scheduler, and Steam
    (lib.mkIf cfg.gaming.enable {
      # Use CachyOS kernel and Valve's LAVD BPF scheduler (only on physical gaming hosts)
      boot.kernelPackages = lib.mkIf (config.mySystem.hardware.gpu != "vm") pkgs.linuxPackages_cachyos;

      # Native NixOS module for sched-ext
      services.scx = {
        enable = config.mySystem.hardware.gpu != "vm";
        scheduler = "scx_lavd"; # LAVD scheduler optimized for gaming/responsiveness
      };

      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        extraCompatPackages = with pkgs; [ proton-ge-bin ];
      };
      programs.gamemode.enable = true;
    })
  ];
}