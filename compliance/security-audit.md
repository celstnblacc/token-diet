# Security Audit Checklist — token-diet

Pre-deployment security review for the RTK + tilth + Serena stack.

## Per-Tool Audit

### RTK

| Check | Command | Pass? |
|---|---|---|
| No known vulnerabilities | `cargo audit --file forks/rtk/Cargo.lock` | |
| No telemetry/analytics | `grep -r "telemetry\|analytics\|ping" forks/rtk/src/` | |
| No hardcoded URLs | `grep -rn "http:/\|https:/" forks/rtk/src/ --include="*.rs"` | |
| No unwrap in production | `grep -rn "\.unwrap()" forks/rtk/src/ --include="*.rs"` (exclude tests) | |
| No unsafe blocks | `grep -rn "unsafe" forks/rtk/src/ --include="*.rs"` | |
| Shell injection review | Review `execute_command` and `Command::new` usage | |
| Exit code propagation | Verify child process exit codes are forwarded | |
| All tests pass | `cargo test --manifest-path forks/rtk/Cargo.toml` | |
| Clippy clean | `cargo clippy --manifest-path forks/rtk/Cargo.toml --all-targets` | |

### tilth

| Check | Command | Pass? |
|---|---|---|
| No known vulnerabilities | `cargo audit --file forks/tilth/Cargo.lock` | |
| No network calls | `grep -rn "reqwest\|hyper\|TcpStream\|http::" forks/tilth/src/` | |
| No telemetry | `grep -rn "telemetry\|analytics\|tracking" forks/tilth/src/` | |
| tree-sitter grammar review | Check compiled C grammars for injection | |
| File access scoping | Verify reads are scoped to project directory | |
| Memory safety (mmap) | Review memmap2 usage for bounds checking | |
| All tests pass | `cargo test --manifest-path forks/tilth/Cargo.toml` | |

### Serena

| Check | Command | Pass? |
|---|---|---|
| No known vulnerabilities | `pip-audit -r forks/serena/requirements.txt` | |
| No telemetry/phoning home | `grep -rn "requests\.\|urllib\|http" forks/serena/src/` | |
| cmd_tools.py review | Review shell execution for injection risks | |
| LSP server downloads | Verify no auto-download at runtime (pre-install in Docker) | |
| File write scoping | Verify writes limited to project + .serena/ | |
| Memory persistence | Review .serena/memories/ for data leakage | |
| No eval/exec | `grep -rn "eval(\|exec(" forks/serena/src/` | |
| All tests pass | `cd forks/serena && pytest` | |
| Docker non-root | Verify Dockerfile runs as non-root user | |
| Docker no network | Verify compose.yml has `network_mode: none` | |

## Supply Chain

| Check | Status |
|---|---|
| Forks on internal Git server (no GitHub dependency) | |
| Submodule URLs point to internal server | |
| Cargo.lock committed (pinned Rust deps) | |
| Python deps pinned in requirements.txt | |
| Docker image built from pinned base (python:3.12-slim) | |
| No `latest` tags in production | |
| SBOM generated (compliance/SBOM.template.json) | |

## Network Isolation

| Check | Status |
|---|---|
| RTK: no outbound connections | |
| tilth: no outbound connections | |
| Serena Docker: `network_mode: none` | |
| LSP servers pre-installed (no auto-download) | |
| No `uvx` at runtime (Docker-based) | |

## Deployment

| Check | Status |
|---|---|
| Binaries signed (codesign / gpg) | |
| Distribution via internal artifact store | |
| Rollback procedure documented | |
| Version pinning in installer scripts | |
| Changelog reviewed for each upstream merge | |

## Audit Schedule

| Frequency | Action |
|---|---|
| Per upstream merge | Full diff review + cargo audit + pip-audit |
| Monthly | Dependency vulnerability scan |
| Quarterly | Full checklist re-evaluation |
| Per release | SBOM regeneration |
