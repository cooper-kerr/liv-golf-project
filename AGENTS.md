# Repository Guidelines

## Project Structure and Current State

- Read `current-status/` before changing the research plan; `project-context/` holds prompts and earlier check-ins.
- `data/reference/` has event/source manifests; `data/staging/observed_leaderboard_rows.csv` is the curated score input; `data/normalized/` has experimental tables. Keep `data/raw/` snapshots untracked. `scripts/` contains the authoritative Ruby build and validator; `docs/` and `reports/` explain fields and coverage.
- Current pilot: 30 sourced events (14 majors, five PGA Tour, three DP World Tour, eight LIV), 2,486 player-event results, 8,302 rounds, and 625 players. Twenty-one fields are complete. All 2024–2025 majors and the 2026 Masters have full fields, but this is not a complete 2018–2026 dataset.

## Reproduce and Validate

Run from the repository root:

```sh
ruby --disable-gems scripts/materialize_observed_data.rb
ruby --disable-gems scripts/validate_observed_data.rb
```

The materializer reads the curated scores and `data/reference/observed_event_sources.csv`, then regenerates normalized CSVs, `source_requests.csv`, and `reports/coverage_report.json`. The older Python scripts are collection scaffolding, not the authoritative build. No separate automated test framework is configured.

## Data Rules and Next Steps

- Record exact source URLs, retrieval dates, field counts, and completeness. Preserve cuts, withdrawals, unknown starts, and blanks; never convert missing results to zero. Check player aliases, unique keys, score sums, and SG zero-centering after additions.
- Field-relative SG requires complete event-round-course scoring groups and is not a cross-tour ability rating. Profile starts are observed lower bounds. Of 5,950 major-panel cells, 3,996 remain unknown; most LIV debut dates are unverified.
- Data Golf historical stats/API require subscription access for much of this period. Source SG, components, driving distance, and season statistics still have zero observations. The 2026 PGA Championship, U.S. Open, and Open need authoritative full-field reconciliation: public secondary tables omit entries or contain score-total conflicts. Cross-check Wikipedia-backed 2024–2025 majors against official scorecards. Preserve 2025 RBC Heritage regulation strokes separately from its playoff.
- Expand regular-tour/LIV event coverage and source-ID crosswalks; collect defined season distance/SG measures where public; update both coverage reports. Use descriptive filenames such as `figure-01-major-participation-by-year.png`.

## Commits and Review

Use short imperative subjects, e.g. `Add major field results`. In PRs, summarize sources, reproduction steps, missingness, and affected figures. Review visual labels, units, periods, and source notes against the data.
