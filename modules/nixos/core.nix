{ config, lib, pkgs, hostName, ... }:

let
  cfg = config.mySystem;
in
{
  options.mySystem = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "francesco";
    };
    secureBoot.enable = lib.mkEnableOption "Secure Boot with Lanzaboote UKI signing";
    autoUpgrade.enable = lib.mkEnableOption "Unattended background updates (uupd style)";
  };

  config = {
    networking.hostName = hostName;
    networking.networkmanager.enable = true;
    networking.nftables.enable = true;
     networking.firewall.enable = true;

    time.timeZone = "Europe/Rome";
    i18n.defaultLocale = "it_IT.UTF-8";

    # Allow proprietary packages (NVIDIA, Steam, VSCode, Discord)
    nixpkgs.config.allowUnfree = true;

    # Enable Flakes and modern nix CLI
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" ];
    };

    # Stage-1 systemd initrd (modern replacement for dracut)
    boot.initrd.systemd.enable = true;

    # Standard systemd-boot (automatically disabled when Lanzaboote Secure Boot is enabled)
    boot.loader.systemd-boot = {
      enable = lib.mkForce (!cfg.secureBoot.enable);
      configurationLimit = 10;
      consoleMode = "max";
    };
    boot.loader.efi.canTouchEfiVariables = true;

    # Secure Boot via Lanzaboote (compatible with Windows dual-boot via sbctl --microsoft)
    boot.lanzaboote = lib.mkIf cfg.secureBoot.enable {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    # Memory optimization (Fedora-style Zram)
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };

    # Audio stack (PipeWire low-latency + Bluetooth LDAC support)
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Primary User account
    programs.zsh.enable = true;
    users.users.${cfg.username} = {
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = [ "wheel" "networkmanager" "video" "input" "libvirtd" "podman" "i2c" ];
      initialPassword = "changeme"; # Change after first boot with `passwd`
    };

    # Nix Helper (nh) for clean diffs and automatic garbage collection
    programs.nh = {
      enable = true;
      clean = {
        enable = true;
        dates = "weekly";
        extraArgs = "--keep 5 --keep-since 7d";
      };
    };

    # Unattended Atomic Upgrades (staged for next boot, like Bazzite uupd)
    system.autoUpgrade = lib.mkIf cfg.autoUpgrade.enable {
      enable = true;
      flake = "/home/${cfg.username}/nixos-config#${hostName}";
      operation = "boot";
      flags = [
        "--update-input" "nixpkgs"
        "--update-input" "home-manager"
        "--update-input" "niri"
        "--update-input" "dux-shell"
        "--no-write-lock-file" # Prevents dirtying git history during background updates
      ];
      dates = "daily";
      randomizedDelaySec = "45min";
      persistent = true;
    };

    # Keep background upgrades completely invisible to CPU/Disk during gaming
    systemd.services.nixos-upgrade = lib.mkIf cfg.autoUpgrade.enable {
      onFailure = [ "nixos-upgrade-notify-failure.service" ];
      serviceConfig = {
        Nice = 19;
        IOSchedulingClass = "idle";
        CPUWeight = 20;
      };
    };

    # Desktop notification if a background upgrade fails
    systemd.services.nixos-upgrade-notify-failure = {
      description = "Notify user on NixOS automatic upgrade failure";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.username;
        Environment = [ "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus" ];
      };
      script = ''
        ERROR_SNIPPET=$(journalctl -u nixos-upgrade.service -n 5 --no-pager -o cat | tail -n 2)
        ${pkgs.libnotify}/bin/notify-send \
          --urgency=critical \
          --app-name="NixOS AutoUpgrade" \
          --icon=dialog-error \
          "Aggiornamento di sistema fallito" \
          "La build in background si è interrotta:\n$ERROR_SNIPPET"
      '';
    };

    system.stateVersion = "26.05";
  };
}