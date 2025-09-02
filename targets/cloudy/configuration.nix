{ pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./disko.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "net.ifnames=0" "boot.shell_on_fail" "panic=30" "boot.panic_on_fail" ];
  
  networking = {
    interfaces = {
      eth0.ipv4.addresses = [{ ipAddress = "10.0.0.104"; prefixLength = 24; }];
    };
    defaultGateway = {
      address = "10.0.0.1";
    };
    nameservers = [ "1.1.1.1" ];
  };

  time.timeZone = "America/Denver";

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
  ];

  services.openssh.enable = true;
  
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDO7lQ5/HFagyOrQKXT9IC1PqBm/Yvi3zThJ7Azawg3lb6FHKUms8FuR5vS5rkrRCaTrs8URHugirIMvXQYxmTMbU51jGsJcWPNfTPm/iWczYUVFHY5TY4BlviWMu0EzHA9pA5bcR8DGjEgJdloPwuQ6eOTda0x9HBNBT8Q0xbiXTjmcYwluqw3iI8Up54f5zR6nC0pMkKTHIjmSLzCnbCBFsZ+aIvtE339oLbQZ5B5Jlw0/lgV1m9/GTn/PUHbUPbgKW3MZ4/kCuqh62UvqdyMa2bjaqPZLfcrNkJSvT8xVxk4enKUfHj5VI1jwG6SJ6s6fc/FUHZJlt3wtGsw08XL ssh-key-2025-09-02"
  ];
}