# RTK vs tilth vs Serena — Three-Way Comparison

Three Rust/Python tools that reduce token waste for AI coding agents, each attacking a different layer of the stack.

## Overview

| | RTK | tilth | Serena |
|---|---|---|---|
| **Purpose** | Compress CLI command output | Smart code reading & navigation | IDE-like symbol navigation |
| **Layer** | Post-execution (output filtering) | Pre-execution (file reading) | Semantic (code understanding) |
| **Approach** | Regex filtering, truncation, dedup | tree-sitter AST outlines + search | LSP-powered symbol resolution |
| **Written in** | Rust | Rust | Python |
| **License** | MIT | MIT | MIT |
| **Repository** | [rtk-ai/rtk](https://github.com/rtk-ai/rtk) | [jahala/tilth](https://github.com/jahala/tilth) | [oraios/serena](https://github.com/oraios/serena) |

## Integration Model

| | RTK | tilth | Serena |
|---|---|---|---|
| **How it plugs in** | Claude Code hook (transparent proxy) | MCP server + CLI | MCP server |
| **Setup** | `rtk init` | `tilth install claude-code` | `claude mcp add serena -- uvx ...` |
| **Agent awareness** | None (passive filter) | Moderate (session dedup, callee expansion) | High (contexts, modes, memories, adaptive prompts) |
| **Requires LSP** | No | No | Yes (auto-downloaded) |
| **Startup** | <10ms | ~18ms CLI, persistent in MCP | LSP cold start (seconds) |

## Efficiency Claims

| | RTK | tilth | Serena |
|---|---|---|---|
| **Metric** | 60-90% token reduction on output | 38-44% cost-per-correct-answer reduction | Symbol-level retrieval (no full-file reads) |
| **Benchmark method** | Input vs output token count | 4-repo navigation tasks, $/correct answer | Community reports, no published benchmark |
| **Accuracy impact** | Neutral (filtering only) | +10% (84% to 94% on Sonnet 4.6) | Qualitative ("game changer for large codebases") |

## Language Support

| | RTK | tilth | Serena |
|---|---|---|---|
| **Scope** | Language-agnostic (filters command output) | 14 languages (tree-sitter grammars) | 40+ languages (LSP servers) |
| **Code parsing** | None (regex on output text) | tree-sitter AST | Full LSP (go-to-def, references, diagnostics) |

## Feature Matrix

| Capability | RTK | tilth | Serena |
|---|---|---|---|
| Compress `git log`, `cargo test`, `npm install` | Yes | - | - |
| Token tracking & analytics (`rtk gain`) | Yes | - | - |
| Structural file outline | - | Yes (AST) | Yes (LSP symbols) |
| Symbol search (definition-aware) | - | Yes (tree-sitter) | Yes (LSP go-to-def) |
| Find all references / callers | - | Yes (tree-sitter) | Yes (LSP find-refs) |
| Cross-codebase rename | - | - | Yes (LSP rename) |
| Symbol-level editing | - | Hash-anchored edits | Yes (insert after symbol) |
| Persistent memory | - | - | Yes (.serena/memories/) |
| Session dedup (avoid re-showing code) | - | Yes | - |
| Diagnostics / compiler errors | - | - | Yes (LSP diagnostics) |
| File dependency graph | - | Yes (tilth_deps) | - |
| Codebase map | - | Yes (--map) | - |
| Web dashboard | - | - | Yes (Flask) |

## Supported Hosts

| Host | RTK | tilth | Serena |
|---|---|---|---|
| Claude Code | Yes (hook) | Yes (MCP) | Yes (MCP) |
| Claude Desktop | - | Yes | Yes |
| Cursor | - | Yes | Yes |
| VS Code | - | Yes | Yes |
| JetBrains IDEs | - | - | Yes (plugin) |
| Codex CLI | - | Yes | Yes |
| Gemini CLI | - | Yes | Yes |
| Others | - | 20+ total | 15+ total |

## Where They Overlap

RTK has **zero overlap** with tilth or Serena. It compresses command output that neither tool touches.

The overlap is **tilth vs Serena** on code navigation:

| Shared capability | tilth | Serena |
|---|---|---|
| File reading (adaptive) | tree-sitter outline for large files | LSP symbol overview |
| Symbol search | tree-sitter definition matching | LSP go-to-definition |
| Find callers/references | tree-sitter structural matching | LSP find-references |

**Key difference**: tilth is faster and lighter (Rust, no LSP, <30ms). Serena is deeper and richer (LSP, rename, diagnostics, 40+ languages, persistent memory).

## Fixing the Overlap

Three approaches, from lightest to most ambitious.

### Option 1: Config-Level Dedup (Zero Code)

Serena's context system can disable tools that tilth handles better. When both are installed, create a Serena context that defers fast operations to tilth:

```yaml
# project.local.yml — when tilth is also installed
context: claude-code-with-tilth
disabled_tools:
  - get_symbols_overview    # tilth outline is faster (Rust, no LSP)
  - find_symbol             # tilth definition search is faster
  - read_file               # tilth adaptive read is smarter
```

Serena keeps what tilth cannot do: `rename_symbol`, LSP-grade `find_referencing_symbols`, diagnostics, memory.

**Result**: tilth handles fast reads and search. Serena handles deep refactoring and LSP-only operations. No duplicate tools exposed to the agent.

**Effort**: 5 minutes. **Risk**: None.

### Option 2: Tiered Routing via MCP Meta-Server (Medium Effort)

Build a routing layer (or extend RTK) that exposes one unified MCP tool set and dispatches internally:

```
Agent request
  |
  +-- "read file" / "find symbol" / "outline"
  |     \--> tilth  (fast, Rust, tree-sitter, <30ms)
  |
  +-- "rename" / "find all references" / "diagnostics"
  |     \--> Serena  (deep, LSP, slower but complete)
  |
  +-- "git log" / "cargo test" / "npm install"
        \--> RTK  (output compression)
```

The agent sees a single coherent API with no duplicates. The router picks the fastest backend that can satisfy the request.

**Result**: Clean separation with automatic fast-path selection.

**Effort**: Days to weeks. **Risk**: Maintenance of the routing logic.

### Option 3: RTK Absorbs the Fast Layer (Most Ambitious)

RTK is already a Rust CLI proxy. Adding structural file reading (what tilth does) is architecturally consistent:

- `rtk read src/main.rs` — adaptive full-file or AST outline
- `rtk symbols src/main.rs` — definition-aware symbol search
- `rtk outline src/` — structural codebase map

This gives RTK two pillars:

1. **Output compression** (existing) — filter `git log`, `cargo test`, `npm install`
2. **Input compression** (new) — smart code reading, structural outlines

Serena stays for LSP-only operations (rename, cross-file references, diagnostics). tilth becomes unnecessary as a separate tool.

**Result**: Two tools instead of three. RTK owns all token optimization. Serena owns all semantic operations.

**Effort**: Weeks to months (tree-sitter integration, MCP server mode). **Risk**: Scope creep, binary size increase.

## Recommendation

Start with **Option 1** (config-level dedup) today. It eliminates the overlap immediately with zero risk.

Evaluate **Option 2** if the agent still wastes turns choosing between tilth and Serena tools.

Consider **Option 3** only if RTK's roadmap includes becoming the single token-optimization layer for AI coding — it changes RTK's identity from "output filter" to "full token optimizer."

## The Ideal Stack

```
+--------------------------------------------------+
|                   AI Agent                        |
+--------------------------------------------------+
         |                |                |
    Code reading     Refactoring     Command output
         |                |                |
    +--------+      +---------+      +--------+
    | tilth  |      | Serena  |      |  RTK   |
    | (fast) |      |  (deep) |      | (filter)|
    +--------+      +---------+      +--------+
    tree-sitter        LSP           regex/truncate
```

Each tool owns its lane. The agent gets maximum token savings with minimum redundancy.
