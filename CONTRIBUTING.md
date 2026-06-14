# Contributing

## Development Workflow

1. Create a branch for each change set.
2. Keep commits scoped (ingestion, reporting, templates, docs).
3. Run validation before opening a PR:

```bash
make test
make purge
make process
make tex
make report
make compile-report
```

## Coding Guidelines

1. Prefer additive changes to existing data contracts.
2. Preserve deterministic output formatting for generated TeX and manifest files.
3. Keep campaign metadata sourced from manifest/inputs, not heuristics.
4. Treat `interaction_residual` as a proxy metric unless replaced with closed-form coupling physics.

## Reporting Changes

When changing report fields or templates:

1. Update token production in `scripts/build_campaign_report.jl`.
2. Update corresponding template placeholders.
3. Verify generated outputs in `reports/cases99_run/generated/`.
4. Confirm report compiles with no blocking TeX errors.

## Documentation Changes

1. Update `README.md` for user-visible workflow changes.
2. Add a dated entry in `CHANGELOG.md`.
3. Update `QUICKSTART.md` if commands or outputs change.
