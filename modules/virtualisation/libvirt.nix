{
  sysModule =
    { config, lib, ... }:
    let
      inherit (lib) mkEnableOption mkIf;
      cfg = config.cfg.virtualisation.libvirt;
    in
    {
      options.cfg.virtualisation.libvirt = {
        enable = mkEnableOption "libvirt";
      };

      config = mkIf cfg.enable {
        programs.virt-manager.enable = true;
        virtualisation = {
          libvirtd.enable = true;
          libvirtd.qemu = {
            swtpm.enable = true;
            verbatimConfig = ''
              cgroup_device_acl = [
                "/dev/null", "/dev/full", "/dev/zero",
                "/dev/random", "/dev/urandom",
                "/dev/ptmx", "/dev/kvm",
                "/dev/userfaultfd",
                "/dev/kvmfr0"
              ]
            '';
          };
          spiceUSBRedirection.enable = true;
        };
      };
    };

  hmModule =
    { sysConfig, lib, ... }:
    let
      inherit (lib) mkIf;
    in
    {
      config = mkIf sysConfig.cfg.virtualisation.libvirt.enable {
        dconf.settings = {
          "org/virt-manager/virt-manager/connections" = {
            autoconnect = [ "qemu:///system" ];
            uris = [ "qemu:///system" ];
          };
        };
      };
    };
}
