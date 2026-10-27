{ ... }:

{
  mySystem = {
    diskDevice = "/dev/vda";
    secureBoot.enable = false; # Keep false for initial install
    autoUpgrade.enable = true;

    hardware = {
      gpu = "vm";
      isOled = false;
      asusVivobook.enable = false;
    };

    roles = {
      desktop.enable = true;
      dev.enable = true;
      gaming.enable = false;
    };
  };
}