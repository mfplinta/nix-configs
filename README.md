## Commands

Clone the private submodule:

```bash
git submodule update --init --recursive
```

Installation:
```bash
# Format disks
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount ./targets/machinename/disko.nix

# Add Clevis/Tang to LUKS (if enabled)
nix-shell -p clevis
echo "password" | clevis encrypt tang '{"url": "http://tang.local"}' > /mnt/root/tang.jwe

# Install system
nixos-install --flake .#hostname \
  --option extra-substituters \
    "https://devenv.cachix.org https://attic.xuyh0120.win/lantian https://codex-cli.cachix.org" \
  --option extra-trusted-public-keys \
    "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc= codex-cli.cachix.org-1:1Br3H1hHoRYG22n//cGKJOk3cQXgYobUel6O8DgSing="
```

Upgrading configuration:

```bash
sudo nixos-rebuild switch --flake .
```

## Needed files

**Pre-install**

- /tmp/secret.key (LUKS)
- /mnt/root/tang.jwe (if enabled)
