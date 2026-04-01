# token-diet

Token optimization stack installer and compliance kit for RTK + tilth + Serena.

## Project structure

```
token-diet/
├── forks/                    # Git submodules — audited forks
│   ├── rtk/                  # celstnblacc/rtk (Rust CLI proxy)
│   ├── tilth/                # celstnblacc/tilth (Rust MCP server)
│   └── serena/               # celstnblacc/serena (Python MCP server)
├── scripts/
│   ├── install.sh            # macOS/Linux installer (--local for air-gapped)
│   ├── Install.ps1           # Windows installer
│   ├── playbook.yml          # Ansible playbook
│   └── build.sh              # Build from forks (no internet)
├── docker/
│   ├── Dockerfile.serena     # Multi-stage, non-root, network_mode: none
│   └── compose.yml
├── config/
│   └── serena-dedup.template.yml
├── compliance/
│   ├── SBOM.template.json    # CycloneDX 1.5
│   ├── LICENSE-THIRD-PARTY.md
│   └── security-audit.md
└── docs/
    └── comparison.md
```

## Build commands

```bash
# Build all tools from local forks (no internet)
bash scripts/build.sh --release

# Build Serena Docker image only
docker build -f docker/Dockerfile.serena -t serena:local .
```

## Install commands

```bash
# Install from upstream (internet required)
bash scripts/install.sh

# Install from local dist/ (air-gapped)
bash scripts/install.sh --local

# Verify installation
bash scripts/install.sh --verify
```

## Submodule workflow

```bash
git submodule update --init --recursive   # first checkout
git submodule update --remote             # pull latest from forks
```

## Conventions

- All three forks are pinned via submodules — never update automatically.
- Security audit checklist: compliance/security-audit.md
- SBOM must be regenerated on each release: compliance/SBOM.template.json
- CHANGELOG.md is append-only — never edit existing entries.
