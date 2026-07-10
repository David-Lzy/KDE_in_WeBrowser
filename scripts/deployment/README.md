# Deployment Scripts

This directory contains host-side deployment tooling.

## Entry Points

- `configure.sh`: interactive bilingual deployment wizard.
- `install.sh`: simple non-interactive local installer.

## Internals

- `lib/configure-flow.sh`: wizard implementation and deployment orchestration.
- `actions/*.sh`: focused host-side actions called by the wizard, installer, or
  advanced users.

The repository intentionally does not keep compatibility wrappers at the old
root-level script paths. Use the paths in this directory for deployment work.
