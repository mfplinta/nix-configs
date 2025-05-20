## Commands

Installation:
```bash
# Format disks
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount ./targets/machinename/disko.nix

# Add Clevis/Tang to LUKS (if enabled)
nix-shell -p clevis
echo "password" | clevis encrypt tang '{"url": "http://tang.local"}' > /mnt/root/tang.jwe

# Install system
nixos-install --flake .#hostname --option 'extra-substituters' 'https://chaotic-nyx.cachix.org/' --option extra-trusted-public-keys "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8=" --option 'extra-substituters' 'https://hyprland.cachix.org/' --option extra-trusted-public-keys "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
```

Upgrading configuration:

```
sudo nixos-rebuild switch --flake .
```

## Needed files

**Pre-install**

- /tmp/secret.key
- /mnt/root/tang.jwe (if enabled)

**Post-install**

- /root/matheus-smbpasswd
