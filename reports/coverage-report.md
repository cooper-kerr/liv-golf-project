# Exploratory collection coverage — 2026-10-19

The dataset has real event-level observations but is a sparse pilot, not the
complete assignment dataset. `coverage_report.json` has the machine-readable
event-by-event gap inventory and tour/year row counts.

| Competition | Sourced events | Player-event rows | Limits |
| --- | ---: | ---: | --- |
| Men's majors | 14 of 35 played | 1,559 | Full fields: 2018 Masters, all eight 2024–2025 majors, and 2026 Masters. Four older major tables are finisher-only. |
| PGA Tour regular | 5 | 325 | Full no-cut fields: 2022 and 2024 Sentry, 2025 RBC Heritage. Two other tables are finisher-only. |
| DP World Tour regular | 3 | 191 | 2022 Tour Championship is full no-cut; other two are finisher-only. |
| LIV Golf | 8 | 411 | Four 2022 events, two 2024 events, and one each in 2025–26; intervening gaps prevent most debut-date verification. |
| Total | 30 | 2,486 | 8,302 completed rounds; 625 distinct observed players. |

Twenty-one fields are verified complete. They support 5,936 round-level calculated
field-relative SG values. No source-reported SG, SG component, or round/event
driving-distance observations are available in this release. The separate
`data/staging/player_season_statistics.csv` contains 552 2026 season observations:
four measures for each of 57 LIV players, 80 of 81 players in the pilot's
2026 Wyndham field, and Jacob Bridgeman on the PGA TOUR. PGA TOUR values came
from search-indexed official profiles with varying crawl ages; the oldest
Wyndham profile was excluded. It also has seven provisional 2018 and 2019
Jordan Spieth observations: six from a secondary restatement and one
driving-distance value shown in a user-provided official PGA TOUR screenshot.
These season aggregates do not supply
event-level variation or pre-major profile values.
The [pre-LIV source audit](pre-liv-pga-season-stat-audit.md) documents the
2018–19 pilot and its remaining source-verification requirements; it is not a
completed control panel.

The observed prelaunch-major cohort has 170 golfers. Its 35-major panel has
5,950 cells: 934 observed starts, 1,020 verified nonparticipations, and 3,996
unknowns. Zeros arise only from complete major fields, not the other 25 majors.
Sixty-one golfers have a
verified first LIV start from the consecutive complete London, Portland, and
Bedminster fields in 2022. Other observed LIV appearances establish treatment
by their date but not exact onset.

The 47,600 profile rows are tour/window slices of **observed** histories.
`data/normalized/experiment_ready_major_panel.csv` joins these into 5,950
golfer-major rows for exploratory work.
Starts, rounds, finishes, and cut rates are not career-complete; cut rates use
only verified complete fields. Sparse, selective coverage can bias exploratory
comparisons. Finishers-only event tables can support finish/score descriptions
but not full-field SG or verified nonparticipation. Regression and final
visualization work should wait for broader field and statistic collection.
Player source IDs are not yet available; longitudinal name matching uses a
reviewed alias list and still needs a fuller identity audit.

The 2024–2026 major coverage is nine of twelve tournaments: all 2024–2025
majors and the 2026 Masters. The other three 2026 majors have inventory rows
only. Historical Data Golf
player statistics and its API were not publicly extractable without a
subscription. Public leaderboards supplied scores but no source-reported SG
or driving distance. Wikipedia was a last-resort source for seven of the
2024–2025 major fields; those fields warrant an official-scorecard cross-check before
causal analysis. The 2024 Open includes three withdrawals, one without a
completed round. The 2025 RBC Heritage winner was decided in a playoff;
the stored four-round total excludes the playoff hole.
Public 2026 PGA Championship, U.S. Open, and Open secondary tables were
reviewed but not loaded: they omit entrants or have multiple score/total
conflicts. Resolve those against authoritative full-field scorecards first.
