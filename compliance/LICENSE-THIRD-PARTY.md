# Third-Party Licenses

All three tools in the token-diet stack are MIT-licensed.

## Direct Dependencies

| Component | Version | License | Source |
|---|---|---|---|
| RTK (Rust Token Killer) | 0.34.3 | MIT | https://github.com/rtk-ai/rtk |
| tilth | 0.5.7 | MIT | https://github.com/jahala/tilth |
| Serena | 0.1.4 | MIT | https://github.com/oraios/serena |

## Transitive Dependencies

Generate full dependency lists with:

```bash
# Rust (RTK + tilth)
cd forks/rtk && cargo license --json > ../../compliance/rtk-licenses.json
cd forks/tilth && cargo license --json > ../../compliance/tilth-licenses.json

# Python (Serena)
cd forks/serena && pip-licenses --format=json > ../../compliance/serena-licenses.json
```

## Known Copyleft Dependencies

Review before enterprise deployment:

```bash
# Check for GPL/LGPL/AGPL in Rust deps
cd forks/rtk && cargo license | grep -i "gpl"
cd forks/tilth && cargo license | grep -i "gpl"

# Check Python deps
cd forks/serena && pip-licenses | grep -i "gpl"
```

## License Compliance Checklist

- [ ] All MIT — include copyright notice in distributions
- [ ] No GPL/AGPL — no copyleft contamination
- [ ] No proprietary — all source available
- [ ] SBOM generated and reviewed (compliance/SBOM.template.json)
- [ ] `cargo license` clean for both Rust projects
- [ ] `pip-licenses` clean for Serena
