# 2026 player season statistics — source audit

Retrieved 2026-10-19. The source-traceable values are in
`data/staging/player_season_statistics.csv` (552 rows in the 2026 subset,
138 golfers). All 57
current 2026 LIV players have four season measures. Of these, 55 share a
project ID with the pilot's 2026 Riyadh field; Travis Smyth and Lee Westwood
appear later in the season but not in that field. Riyadh-only Ben Schmidt and
Ollie Schniederjans have no published 2026 season rows on the current LIV
stats listing. On the PGA TOUR side, the collection includes 80 of 81 players
in the pilot's 2026 Wyndham field plus Jacob Bridgeman. Tyler Collet's indexed
stats snapshot predated his Wyndham start, so his season statistics were
excluded. Other PGA golfers in the pilot have no season-statistic rows yet.

| Tour | Players | Measures per player | Source |
| --- | ---: | --- | --- |
| LIV | 57 | Scrambling %, GIR %, putting average per hole, driving distance in yards | [LIV player profiles](https://www.livgolf.com/stats/2026/players/all-events/all-stats), with each exact profile URL on its rows |
| PGA TOUR | 81 | Scrambling %, GIR %, putting average on GIR, driving distance in yards | [Jacob Bridgeman stats](https://www.pgatour.com/player/60004/jacob-bridgeman/stats) and the exact player profile URL on each row |

For LIV, the profiles publish scrambling successes/attempts, greens hit/holes,
total putts, and driving distance. The 57 extracted scrambling and GIR
percentages agree with their published fractions to rounding; putting averages
agree with total putts divided by holes. The [LIV stats index](https://www.livgolf.com/stats/2026/players/all-events/all-stats)
calls putting average a per-round measure, but the published values around
1.6 are reproduced by putts per hole. The denominator interpretation is an
inference from the profile counts. For example, [Jon Rahm's profile](https://www.livgolf.com/players/jon-rahm)
shows 1,388 putts over 864 holes, or 1.61 putts per hole.

PGA TOUR profiles were available through search-indexed official snapshots;
direct page fetching returned HTTP 403. The included Wyndham snapshots were
crawled within roughly two weeks of retrieval, and each crawl age is recorded
in `measurement_definition`. They are not one synchronized end-of-season
snapshot. Bridgeman's profile snapshot was
crawled 2026-10-14. His
published 2026 values are 62.95% scrambling (367/583), 66.95% GIR
(1,181/1,764), 1.693 putts on GIR (1,999/1,181), and 305.1 yards across 196
measured drives. The PGA TOUR [driving-distance definition](https://www.pgatour.com/stats/detail/101)
uses two preselected measured holes per round. LIV's profile does not state
whether its driving-distance sample follows the same rule. Scrambling and GIR
are the closest descriptive cross-tour measures here. Putting averages have
different denominators and are stored as distinct metrics.

The LIV season window runs from Riyadh (2026-02-04) through Indianapolis
(2026-08-23), the last listed individual event. The PGA TOUR window for
Bridgeman runs from his Sony Open start (2026-01-15) through the Baycurrent
Classic (2026-10-11). Other PGA rows use 2026-01-01 to the retrieval date
2026-10-19 as inclusive bounds; their exact last observed event is not known
from the indexed stats snippet. The sources expose season totals; no
verified player-event scrambling, GIR, putting, or driving-distance observations
were extracted. The pilot's existing event/round score tables still support
score-based event variation for their 30 sourced events.

Identity note: LIV lists Younghan Song. The 2026 Riyadh result uses the
project ID `young-han-song`, while older Open results use `song-young-han`.
The 2026 LIV season statistics follow the Riyadh ID. Reconcile the duplicate
before longitudinal player analysis. LIV lists Josele Ballester; the 2026
Riyadh result uses `jose-luis-ballester`, while two 2025 majors use that ID
and `josele-ballester` separately. The season statistics follow the Riyadh ID.
