{ config, lib, ... }:

{
  options.mySystem.diskDevice = lib.mkOption {
    type = lib.types.str;
    default = "/dev/vda";
    description = "Target disk device path for disko partitioning.";
  };

  config.disko.devices = {
    disk.main = {
      type = "disk";
      device = config.mySystem.diskDevice;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "luks";
              name = "encrypted-container";
              # force = true; # optional
              settings = {
                allowDiscards = true; # Suggested for SSDs (TRIM)
              };
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                # Subvolumes layout ready for future Impermanence adoption without formatting
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}