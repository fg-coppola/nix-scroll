{ ... }:

{
  mySystem = {
    diskDevice = "/dev/nvme0n1"; # Replace with actual disk /dev/disk/by-id/...
    secureBoot.enable = true;
    autoUpgrade.enable = true;

    hardware = {
      gpu = "nvidia";
      isOled = false;
      asusVivobook.enable = false;
    };

    roles = {
      desktop.enable = true;
      dev.enable = true;
      gaming.enable = true; # Enables CachyOS kernel, scx_lavd, Steam, and Amethyst Flatpak
    };
  };
}