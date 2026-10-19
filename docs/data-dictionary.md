# Data dictionary

All dates are ISO-8601 (`YYYY-MM-DD`). Blank means unknown or not published;
it never means zero. `source_url` and `retrieved_at` are required for observed
records. IDs are internal, stable identifiers and are never recycled.

## Reference tables

| Table | Key | Purpose |
| --- | --- | --- |
| `events` | `event_id` | One row per tournament. Co-sanctioned events appear once, with the primary reported tour retained. |
| `players` | `player_id` | Canonical player identity. |
| `player_aliases` | `alias, source_id` | Source spellings and source-specific IDs mapped to an internal player. |
| `liv_appearances` | `player_id, event_id` | Every actual LIV start, including substitutes and former members. |

`observed_event_sources.csv` documents the 20 collected event pages,
published field sizes, finisher counts, and whether the extracted field is
verified complete. `observed_leaderboard_rows.csv` is the compact,
source-transcribed input to the pilot materializer. The current
`liv_appearances.csv` is **not** an exhaustive LIV history; withdrawal rows
with no round score have unknown start status and are excluded.
Pilot `player_id` values are normalized name slugs, with reviewed aliases;
source-specific player IDs have not yet been collected. Audit identity
crosswalks before merging additional years or using the data longitudinally.

`competition_group` is one of `pga`, `dpwt`, `liv`, or `major`.
`format` is `stroke_play`, `match_play`, `team`, or `modified`; only standard
stroke-play results can receive calculated field-relative SG. `cut_rule` is
`after_36_holes`, `none`, `other`, or `unknown`.

## Observed results

| Table | Key | Key fields |
| --- | --- | --- |
| `player_round_results` | `event_id, player_id, round_number` | `strokes` is the actual round stroke score; all reported Data Golf values remain in their `source_*` columns. |
| `player_event_results` | `event_id, player_id` | Original finish text, reported numeric position, statuses, and completed-round count. |
| `player_season_statistics` | `player_id, season, tour, metric` | Source-linked season aggregates. `measurement_definition` and observation bounds are mandatory; source grade must be checked before analysis. |

The 2026 season-statistics staging table now contains `scrambling_pct`,
`greens_in_regulation_pct`, and `driving_distance_yards` for 57 LIV players,
80 players from the pilot's Wyndham field, and Jacob Bridgeman. LIV
`putting_average_per_hole` is the published putting
average: its displayed total putts divided by holes played reproduces the
value, despite the stats index describing it as a per-round average. PGA TOUR
`putting_average_on_gir` uses putts on greens hit in regulation divided by
greens hit. These two putting measures have different denominators and must
not be plotted as the same metric. The PGA TOUR driving-distance figure uses
two preselected measured holes per round; LIV does not specify an equivalent
sampling rule on its profile. `observation_start` and `observation_end` bound
the published tour season or retrieval window, not each player's first and
last start. PGA TOUR player-page values came from search-indexed official
snapshots; each row records the crawl age in its definition.

Seven 2018 and 2019 Jordan Spieth pilot rows include six secondary-source
restatements and one driving-distance observation from a user-provided
official PGA TOUR screenshot. `season=2018` denotes the PGA TOUR
2017–18 season and `season=2019` denotes 2018–19. `sg_total_per_round` and
`sg_putting_per_round` use measured
rounds as their denominator and are distinct from the calculated
`field_relative_sg` in event/round tables. See the
[pre-LIV season-stat audit](../reports/pre-liv-pga-season-stat-audit.md) for
source precision and reconciliation status.

Event `completion_status` is `completed`, `missed_cut`, `withdrawn`,
`disqualified`, `did_not_start`, or `incomplete`. `start_status` is `started`,
`did_not_start`, or `unknown` when a scoreless withdrawal does not prove an
actual start. `cut_outcome`
is `made_cut`, `missed_cut`, `not_applicable`, `withdrawn`, `disqualified`, or
`unknown`. A no-cut event uses `not_applicable`; a withdrawal is never recoded
as a missed cut. `is_scoring_group_complete` is `yes` only after the complete
field for that event-round-course group has been loaded.

`driving_distance_yards` is a tournament/round observation. Its
`distance_measurement` must state the publisher's definition (for example,
"all measured drives"), because it is not interchangeable with season average.

## Derived tables

| Table | Key | Definition |
| --- | --- | --- |
| `player_round_results_normalized` | round key | Adds `field_relative_sg = complete-group mean strokes - player strokes`; blank without a complete standard stroke-play group. |
| `player_event_results_normalized` | event-result key | Adds derived completed rounds, average SG, first-two-round SG, and finishing percentile among classified finishers. |
| `major_participation_panel` | `player_id, event_id` | Observed primary cohort: a major start before `2022-06-09`; verified nonparticipation is zero, unresolved coverage is `unknown`. Also carries treatment status at major start. |
| `profile_snapshots` | `player_id, event_id, profile_window, profile_tour` | Only results ending before the major start date. |
| `verified_liv_debuts` | `player_id` | First LIV starts proven by consecutive complete fields from the inaugural event. |
| `experiment_ready_major_panel` | `player_id, event_id` | Wide join of major participation/treatment and tour-separated annual/trailing profiles; `*_observed_starts` and `*_observed_rounds` are coverage-limited counts. |

In `profile_snapshots`, `starts` and `rounds_completed` count **observed**
results only and are lower bounds when tour inventory is incomplete. Cut rates
use only verified complete fields. `treatment_status` is `1` by an observed
actual LIV start, `0` before launch or before a verified future debut, and
`unknown` otherwise. A blank `first_liv_start_date` means exact onset has not
been verified, even when `treatment_status` is `1` by a later appearance.

Finishing percentile is `(N - finish_position) / (N - 1)` for `N > 1`, so the
winner is 1 and the last classified finisher is 0. Tied positions retain the
published shared position. Missed cuts, withdrawals, and disqualifications have
no invented percentile.
