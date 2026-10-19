# Golf research data foundation

This repository now contains a **populated exploratory dataset**, not just CSV
templates. It covers 30 sourced individual stroke-play tournaments across the
PGA Tour, DP World Tour, LIV Golf, and men's majors from 2018 through 2026.
The 35 played majors are inventoried, but only 14 have observed player
results. It is **not** a complete 2018–2026 event universe and is not ready for
causal estimates without further collection and coverage assessment.

The source rows include 2,486 player-event results and 8,302 completed rounds.
Twenty-one event fields are verified complete. Nine published tables contain only
classified finishers (or otherwise incomplete scoring groups); missed cuts and
nonparticipants in those events remain unknown, never zero. The official 2018
Masters PDF supplies 53 classified finishers and 34 missed cuts. All eight
2024–2025 majors have full final fields, as does the 2026 Masters. The other
three 2026 majors remain unsourced: their accessible secondary tables contain
arithmetic inconsistencies or omit entrants. Selected 2024–2026 LIV/PGA Tour
fields also support player-level analysis. Source URLs,
retrieval date, field checks, and gaps are in
`data/reference/observed_event_sources.csv` and `reports/coverage_report.json`.

## Reproduce the populated pilot

Ruby 2.6+ with the standard library is sufficient. From the repository root:

```sh
ruby --disable-gems scripts/materialize_observed_data.rb
ruby --disable-gems scripts/validate_observed_data.rb
```

The materializer reads `data/staging/observed_leaderboard_rows.csv` and the
event-source manifest, then regenerates the populated staging and normalized
tables and JSON coverage report. The validator independently checks keys,
field sizes, score/round assumptions, SG zero-centering, major-panel zeros,
and profile time windows. The extracted source facts are versioned; raw page
snapshots are not. To add events, document their URL and field completeness
before appending score rows. See `docs/collection-protocol.md`.
The materializer also regenerates the 30-URL fetch manifest in
`data/reference/source_requests.csv`.

The earlier Python fetch/build scripts remain as expansion scaffolding; they
are **not** the reproduction path for this pilot and should not be run over its
outputs. In particular, they do not yet implement the pilot's conservative
LIV-debut verification. The Ruby materializer is authoritative for these CSVs.

## Key outputs and limits

- `data/normalized/events.csv`: 35 major inventory rows plus 16 observed
  non-major events. An inventory row does not imply player-result coverage.
- `data/normalized/player_round_results_normalized.csv` and
  `player_event_results_normalized.csv`: observed scores, finishes, cuts, and
  derived field-relative SG where the scoring group is complete.
- `data/normalized/verified_liv_debuts.csv`: first actual starts verified from
  the complete initial three LIV fields. Later observed LIV starts prove
  treatment by that date, but not the exact debut date.
- `data/normalized/major_participation_panel.csv`: observed prelaunch-major
  cohort, with `1`, verified `0`, or `unknown` participation.
- `data/normalized/profile_snapshots.csv`: annual and trailing-365-day,
  tour-separated **observed** histories before each major. Sparse source
  coverage means these are lower-bound starts/rounds, not complete careers.
- `data/normalized/experiment_ready_major_panel.csv`: one row per
  observed-cohort golfer and major, joining the participation/treatment panel
  to prefixed annual and trailing tour profiles for quick exploratory work.

The season-statistics CSV is still header-only. Source-reported SG, SG
components, and driving distance have **zero observations**; they have not been
fabricated from scorecards. Field-relative SG is complete-field mean strokes
for the same event, round, and course minus player strokes. It is not Data
Golf's field-strength-adjusted “true” SG and is not a cross-tour ability
rating. Consult `reports/coverage-report.md` and `docs/data-dictionary.md`
before experimenting.
