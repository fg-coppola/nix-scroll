{ ... }:

{
  mySystem = {
    diskDevice = "/dev/nvme0n1"; # Replace with actual disk /dev/disk/by-id/...
    secureBoot.enable = true;
    autoUpgrade.enable = true;

    hardware = {
      gpu = "hybrid-nvidia";
      isOled = true;             # Enables Niri window dimming & Dux bar auto-hide
      asusVivobook.enable = true; # Enables FocalTech FT9366 shim, battery 80%, and WMI backlight
    };

    roles = {
      desktop.enable = true;
      dev.enable = true;
      gaming.enable = false;
    };
  };
}