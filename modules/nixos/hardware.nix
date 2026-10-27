{ config, lib, pkgs, ... }:

let
  cfg = config.mySystem.hardware;

  # Pure Nix derivation to build custom libfprint for proprietary fingerprint reader
  libfprintFocaltech = pkgs.libfprint.overrideAttrs (oldAttrs: {
    pname = "libfprint-focaltech-ft9366";
    src = pkgs.fetchFromGitHub {
      owner = "leopalladium";
      repo = "focaltech-ft9366-arch-shim";
      rev = "main";
      # On first build, Nix will tell the exact sha256 hash to paste here
      hash = lib.fakeHash;
    };
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [
      pkgs.gcc
      pkgs.pkg-config
      pkgs.patchelf
      pkgs.autoPatchelfHook
    ];
    buildInputs = (oldAttrs.buildInputs or []) ++ [
      pkgs.glib
      pkgs.libgusb
      pkgs.pixman
      pkgs.nss
      pkgs.systemd
    ];
    buildPhase = ''
      # Compile the compatibility proxy-shim against glib-2.0
      gcc -shared -fPIC -Wl,--version-script=shim.map -o focaltech-shim.so shim.c \
        $(pkg-config --cflags --libs glib-2.0) -ldl
    '';
    installPhase = ''
      mkdir -p $out/lib $out/lib/udev/rules.d
      cp libfprint-2.so.2.0.0 $out/lib/
      cp focaltech-shim.so $out/lib/
      ln -s libfprint-2.so.2.0.0 $out/lib/libfprint-2.so.2
      ln -s libfprint-2.so.2.0.0 $out/lib/libfprint-2.so

      # Inject the shim into the proprietary driver binary
      patchelf --add-needed $out/lib/focaltech-shim.so $out/lib/libfprint-2.so.2.0.0
    '';
  });
in
{
  options.mySystem.hardware = {
    gpu = lib.mkOption {
      type = lib.types.enum [ "vm" "nvidia" "hybrid-nvidia" "headless" ];
      default = "vm";
    };
    isOled = lib.mkEnableOption "OLED panel burn-in protection tweaks";
    asusVivobook.enable = lib.mkEnableOption "ASUS Vivobook WMI, battery threshold, and FocalTech fingerprint fixes";
  };

  config = lib.mkMerge [
    # 1. Graphics & GPU configuration
    {
      hardware.graphics = {
        enable = cfg.gpu != "headless";
        enable32Bit = cfg.gpu != "headless";
      };
      # Enable I2C for external monitor brightness control
      hardware.i2c.enable = true;
      hardware.bluetooth.enable = true;
    }

    # 2. NVIDIA Proprietary Open Kernel Modules (Desktop & Hybrid Laptop)
    (lib.mkIf (cfg.gpu == "nvidia" || cfg.gpu == "hybrid-nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = true;
        powerManagement.finegrained = cfg.gpu == "hybrid-nvidia";
        open = true;
        nvidiaSettings = true;
      };
    })

    # 3. ASUS Vivobook & FocalTech FT9366 Customizations
    (lib.mkIf cfg.asusVivobook.enable {
      # Replaces /usr/lib/dracut/dracut.conf.d/asus-backlight.conf
      boot.initrd.kernelModules = [ "asus_wmi" "asus_nb_wmi" ];

      # Replaces /usr/lib/modprobe.d/asus_wmi.conf (automatically included in initrd by NixOS)
      boot.extraModprobeConfig = ''
        options asus_wmi fnlock_default=N
      '';

      # Turn on keyboard backlight inside stage-1 initrd at the LUKS prompt (if applicable)
      boot.initrd.services.udev.rules = ''
        SUBSYSTEM=="leds", KERNEL=="asus::kbd_backlight", ATTR{brightness}="1"
      '';

      # Replaces 80-focaltech-fix.rules, 90-asus-keyboard-backlight.rules, and 99-asus-battery.rules
      services.udev.extraRules = ''
        # Disable autosuspend for FocalTech FT9366 (2808:a658) fingerprint reader
        ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2808", ATTR{idProduct}=="a658", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"

        # Turn on ASUS keyboard backlight at boot
        SUBSYSTEM=="leds", KERNEL=="asus::kbd_backlight", ATTR{brightness}="1"

        # Set battery charging limit to 80% and grant write permissions to wheel group
        ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT[0-9]", ATTR{charge_control_end_threshold}="80", MODE="0664", GROUP="wheel"
      '';

      # Declaratively enable fprintd with the patched FocalTech driver (auto-configures PAM)
      services.fprintd = {
        enable = true;
        package = pkgs.fprintd.override { libfprint = libfprintFocaltech; };
      };

      # Replaces /usr/lib/systemd/system/fprintd-resume.service
      systemd.services.fprintd-resume = {
        description = "Reset FocalTech fingerprint sensor after resume";
        after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
        wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl restart fprintd";
        };
      };
    })
  ];
}