# Repository Guidelines

## Project Structure & Module Organization

This repository is a NixOS flake for multiple machines. `flake.nix` defines inputs, formatter checks, overlays, and `nixosConfigurations`. Machine-specific systems live in `targets/<host>/`, with each target typically containing `configuration.nix`, `hardware-configuration.nix`, and optional `disko.nix`. Shared NixOS and Home Manager modules live in `modules/`; broader reusable configuration bundles live in `common/`. Local packages and scripts are in `pkgs/`, including `pkgs/scripts/`. Private host data and secrets are kept in `private/`; avoid exposing secret material in reviews or generated output.

## Build, Test, and Development Commands

- `nix fmt`: format the repository using `treefmt-nix` and `nixfmt`.
- `nix flake check`: run flake checks, including the formatting check.
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`: build a host configuration without switching.
- `rebuild ~/nix-configs/?submodules=1`: apply a configuration to the current machine.

Known hosts include `mfp-nix-workstation`, `mfp-nix-laptop`, `tiny`, `cloudy`, and `gateway`.

## Binary Cache Policy

Prefer package definitions that can be fetched from configured binary caches. Do not override package arguments, sources, or build inputs when that would force an expensive local rebuild. Make an exception only when the change is a cheap post-build adjustment, such as patching compiled binaries or shebangs, and does not require recompiling the package or its dependency closure.

## Coding Style & Naming Conventions

Use Nix formatting from `treefmt.nix`; do not hand-align code against formatter output. Prefer small focused modules with explicit option names and imports. Name host directories after their flake configuration host, and keep reusable package definitions under `pkgs/*.nix`. Shell scripts in `pkgs/scripts/` should be executable and use clear lowercase names such as `rebuild` or `toggle-scale`.

## Testing Guidelines

There is no separate unit test suite. Treat `nix flake check` as the baseline validation before submitting changes. For host changes, also build the affected host with `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`. When editing disk layout, secrets, networking, or boot configuration, note whether the change was only evaluated or also deployed.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, often scoped by host in parentheses, for example `(laptop) fix flameshot` or `(workstation,laptop) add hud`. Keep commits focused by host or feature. Pull requests should describe the affected host(s), list validation commands run, and call out risky areas such as disk formatting, secret handling, remote services, or rebuild requirements.
