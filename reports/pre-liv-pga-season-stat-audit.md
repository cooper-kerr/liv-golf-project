# Pre-LIV PGA TOUR season-stat audit

Retrieved 2026-10-19. The PGA TOUR player profile exposes historical-season
selectors, but the historical stat table could not be fetched directly in this
environment (HTTP 403 through the web reader; local network DNS unavailable).
The seven 2018 and 2019 Spieth rows in `data/staging/player_season_statistics.csv`
are a **source-audited pilot**, not a complete or analysis-ready control panel.
Six were initially collected from a secondary TOUR-stat restatement; one
driving-distance row is supported by a user-provided screenshot of the
official PGA TOUR season view. `season=2018` means 2017–18 and `season=2019`
means 2018–19, not calendar years (see the official
[2018](https://pgatourmedia.pgatourhq.com/schedule?year=2018) and
[2019](https://pgatourmedia.pgatourhq.com/schedule?year=2019) schedules).

| Season | SG: Total / round | SG: Putting / round | Scrambling |
| --- | ---: | ---: | ---: |
| 2017–18 | [+0.830](https://otisgolf.com/players/jordan-spieth) | [−0.034](https://otisgolf.com/leaders/sg-putting/2017-2018) | [61.63%](https://otisgolf.com/leaders/scrambling/2017-2018) |
| 2018–19 | [+0.459](https://otisgolf.com/players/jordan-spieth) | [+0.862](https://otisgolf.com/leaders/sg-putting/2018-2019) | [62.00%](https://otisgolf.com/leaders/scrambling/2018-2019) |

Both SG columns are per measured round, with 66 measured rounds in each
season. The exact source URL and source rank are retained on each staging
row. The [StatMuse season table](https://www.statmuse.com/pga/ask/jordan-spieth-career-stats-year-by-year)
also offers 2018–19 GIR (62.8%), but that value was **not imported**: its
2017–18 scrambling figure (62.8%) conflicts
with the [TOUR-stat restatement](https://otisgolf.com/leaders/scrambling/2017-2018)
(61.63%), indicating that source/denominator reconciliation is needed.

The user's 2026-10-19 screenshot of the
[official Spieth stats page](https://www.pgatour.com/player/34046/jordan-spieth/stats)
visibly selects `PGA Tour` and `Season 2018-2019`. It shows **Driving Distance
295.2 yards, rank 88**, and independently confirms **SG: Putting +0.862,
rank 2**. Driving distance is now a seventh staging row with source ID
`pga_official_user_screenshot`. The screenshot is attached to the
conversation, not archived in the repository, so its provenance should be
rechecked from the live page or a retained image before publication.

The [PGA TOUR's retrospective](https://www.pgatour.com/article/news/latest/2019/10/18/jordan-spieth-off-to-strong-start-the-cj-cup-at-nine-bridges)
independently reports Spieth's 2019 SG: Putting rank as second, SG:
Off-the-Tee rank as 176th, and SG: Approach rank as 145th. These official
rank checks support the season identification but do not verify the mirrored
SG: Total average. The screenshot above does verify the 2019 SG: Putting
average. The secondary [OTIS SG: Total series](https://otisgolf.com/players/jordan-spieth)
also lists Spieth at +0.137 in 2019–20 and +1.069 in 2020–21. Those values
have **not** been added to staging because this pilot is not yet a complete
pre-treatment player-season panel. StatMuse's displayed putting average is
rounded to 1.7 and is too coarse for this import.

## Reproducibility of the profile workflow

The screenshot establishes a viable **manual** retrieval procedure for this
player-season: open the player stats page, select `PGA Tour`, select the
historical season, and transcribe the displayed statistic value and rank,
separately recording the season label, player ID, source URL, and retrieval
date. The same profile layout appears on other player pages, so this is a
reasonable collection route to test for additional golfers. It does **not**
yet demonstrate that the historical season selection persists in a shareable
URL or that an automated scraper can reproduce the selected view. Direct
page/API access and browser automation were unavailable in this environment;
do not claim a working bulk extractor until several other players and years
have been independently fetched and validated.

## Collection and identification requirements

1. For manual PGA TOUR checks, retrieve official historical stat views for
   selected player-seasons, starting with 2018–2021 pre-treatment seasons.
   Collect SG total and components, driving distance, GIR, scrambling, and
   putting average where displayed, with exact stat definitions, precision,
   rank, measured rounds/opportunities, URL, and retrieval date. Reconcile
   the pilot rows before treating them as official observations. The
   [automation investigation](historical-stat-automation-investigation.md)
   explains why bulk scraping of PGA TOUR pages is not an approved route
   under the site's current Terms, and assesses a licensed round-data option.
2. Extend the same panel through post-2022 seasons for non-LIV comparison
   golfers. For LIV joiners, preserve missing PGA TOUR season stats after
   exit; do not interpret absence as zero or substitute LIV's differently
   defined metrics into a PGA TOUR outcome. Historical PGA TOUR season
   statistics can help match or stratify comparable golfers by pre-LIV
   ability and check pre-treatment trends.
3. Keep the study's primary outcomes at the player-by-major or player-round
   level, where joiners and nonjoiners face the same field and course. Define
   treatment at each golfer's verified first LIV start and compare changes
   with never-joining golfers who had similar pre-2022 records. Do not use
   post-treatment season performance as a control in the causal model.
4. Spieth is one never-LIV comparison candidate, not a control group by
   himself. Major participation, major performance, and event-level SG still
   require broader authoritative event coverage and identity reconciliation.

This pilot changes season-stat coverage only. It does not add any observed
2019 major results or source-reported event/round SG observations.
