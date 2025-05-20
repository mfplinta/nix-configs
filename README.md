## Commands

Installation:
```
# Format disks
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount ./targets/machinename/disko.nix

# Install system
nixos-install --flake .#hostname
```

Upgrading configuration:

```
sudo nixos-rebuild switch --flake .
```

## Needed files

**Pre-install**

- /tmp/secret.key

**Post-install**

- /root/tang.jwe
- /root/matheus-smbpasswd
