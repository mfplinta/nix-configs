{
  sysModule =
    { lib, ... }:
    {
      config = lib.mkMerge [
        {
          services.openssh.enable = true;
          services.openssh.settings.Macs = lib.mkOptionDefault [
            "hmac-sha2-512"
          ];
          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDO7lQ5/HFagyOrQKXT9IC1PqBm/Yvi3zThJ7Azawg3lb6FHKUms8FuR5vS5rkrRCaTrs8URHugirIMvXQYxmTMbU51jGsJcWPNfTPm/iWczYUVFHY5TY4BlviWMu0EzHA9pA5bcR8DGjEgJdloPwuQ6eOTda0x9HBNBT8Q0xbiXTjmcYwluqw3iI8Up54f5zR6nC0pMkKTHIjmSLzCnbCBFsZ+aIvtE339oLbQZ5B5Jlw0/lgV1m9/GTn/PUHbUPbgKW3MZ4/kCuqh62UvqdyMa2bjaqPZLfcrNkJSvT8xVxk4enKUfHj5VI1jwG6SJ6s6fc/FUHZJlt3wtGsw08XL ssh-key-2025-09-02"
          ];
        }
      ];
    };
}
