# Historical golfer statistics: automation investigation

Investigated 2026-10-19. This is a source/access and data-design assessment,
not a completed bulk extraction. The [Spieth source audit](pre-liv-pga-season-stat-audit.md)
documents the existing seven-row 2018–19 pilot.

## Decision

The screenshot-backed PGA TOUR player-page workflow is reproducible **manually**
for a player and selected season, but it is not an approved bulk-collection
route. [PGA TOUR's current Terms of Use](https://www.pgatour.com/company/terms-of-use)
section 7(C) prohibits automated processes that monitor, copy, or download
site data, expressly including archival statistics; section 7(E) also restricts
reverse engineering. Do not write or run a player-profile/stat-table scraper,
browser bot, or undocumented-endpoint client without express permission.
The screenshot proves only the displayed 2018–19 Spieth values, not an API or
permission for large-scale extraction.

The most promising authorized programmatic route is the
[Data Golf Historical Raw Data API](https://datagolf.com/api-access), conditional
on subscription **and** confirmation that the proposed research, retention,
and publication are permitted. Its [subscription page](https://datagolf.com/subscribe)
currently lists Scratch PLUS annual at **$270/year**; the monthly PLUS plan
does *not* include historical archive endpoints. No subscription was bought
or authenticated archive query made. [Data Golf's terms](https://datagolf.com/terms-and-conditions)
limit its website/API content to personal, non-commercial use and prohibit
redistribution or transfer of content. Ask Data Golf whether this student
project and any public repository, paper, or figures fit those terms before
purchase or import. Keep licensed raw rows out of the public repository unless
permission specifically allows publication.

## What the licensed API could supply

The documented event-list and `historical-raw-data/rounds` endpoints accept
tour, calendar year, and event ID (`all` for a tour-year), returning round-level
scores, SG, and traditional stats. Documented PGA coverage is 2004–2026,
other tours 2017–2026, with a shared Data Golf player ID; the API is limited
to [45 requests/minute](https://datagolf.com/api-access). This is a better
collection unit than one request per player-season: retrieve each tour-year
once, then identify treated golfers and eligible controls locally.

[Data Golf's field notes](https://datagolf.com/raw-data-notes) require
metric-specific caution:

| Measure | Useful for baseline? | Important distinction |
| --- | --- | --- |
| SG total, OTT, approach, around-green, putting | Yes, where observed | Component SG is available at ShotLink-equipped PGA events; `sg_total` is Data Golf's round/course-relative calculation. Component sums can differ slightly from total. |
| Driving distance | Yes, with a definition flag | With shot-level data, mean of all par-4/5 drives; in `basic` events, mean of two measured drives. Neither should silently be labeled the PGA TOUR's published season-card average. |
| GIR and driving accuracy | Yes, where observed | Shot-level and `basic` event definitions differ; Data Golf changed fringe/intermediate-rough treatment in June 2023. |
| Scrambling | Yes, but not interchangeable | Data Golf uses around-the-green shots from within 50 yards holed in two or fewer, excluding chip-outs; this is not necessarily PGA TOUR season-card scrambling after a missed GIR. |
| Putting average | Not established from this API | The documented raw-round fields include SG: Putting, not a clearly equivalent published putting-average field. Keep the separate PGA/LIV putting-average metrics and denominators distinct until a permitted source or raw count definition is verified. |

The API's `sg_categories` and `traditional_stats` availability flags distinguish
full, partial, basic, and absent data. Round-level LIV SG categories are noted
only for [stroke-play events since 2024](https://datagolf.com/raw-data-notes),
so do not impute 2022–23 LIV SG components. The historical **event-finish**
endpoint currently documents only 2025–26 PGA events; use the historical
**raw-round** endpoint for earlier scores and event variation. A free
[2021 Masters sample](https://datagolf.com/raw-data-archive) is available for
schema exploration, but one sample does not establish coverage for every
year/event/metric.

## Research panel design

1. Freeze the target population before matching: all golfers with a verified
   pre-LIV PGA TOUR start in the chosen 2018–2021 window, plus pre-LIV
   golfers on other tours if the estimand includes them. Preserve everyone
   initially; classify treated by verified first LIV start and identify
   never-LIV eligible controls only after the exposure inventory is complete.
   The current **170-player prelaunch-major cohort** is a narrower analysis
   population, not the entire PGA player universe.
2. Preserve one source row per `source/tour/event/year/player/round`, including
   Data Golf and PGA IDs where supplied, course, event date, SG/traditional
   availability, each metric's missingness and definition, retrieval date,
   and source version. Build reviewed player and event crosswalks to existing
   repo IDs; never join on name alone. Keep source snapshots in untracked
   `data/raw/`, subject to the data license.
3. Aggregate season SG as the **mean of observed, eligible round SG values**;
   retain measured-round count and event count. For percentages and distance,
   publish an explicitly named Data Golf-derived summary with its count and
   definition regime, not a purported reproduction of PGA TOUR season-card
   values. Do not average published event percentages as though their
   opportunity denominators were equal. Missing metric rounds remain missing.
   Store calendar year and PGA TOUR season separately; 2018–19 is not calendar
   2019.
4. Keep event/round outcomes separate from season baselines. A 2022 joiner
   must be censored at their **first LIV start date**, not treated as wholly
   untreated throughout 2022. Use 2018–2021 as the common pre-treatment
   window; optionally include strictly pre-debut 2022 events in a
   time-indexed analysis. Do not adjust the LIV-effect model for
   post-treatment SG or driving distance. Major performance remains the more
   directly comparable post-switch outcome, since PGA and LIV regular-tour
   fields/round structures differ.
5. Report per-player/year/event/metric coverage and the fraction of candidate
   treated and control golfers with at least one and multiple pre-treatment
   measurements. Do not interpret absent PGA data after a move to LIV as
   performance zero. Preserve withdrawals and cuts from the existing event
   model; Data Golf generally supplies completed rounds only.

## Minimum pilot before scaling

After access and publication rights are confirmed, retrieve Data Golf's player
and historical event lists, then a bounded sample of 2018 and 2019 PGA events
that includes Jordan Spieth plus several eventual LIV and never-LIV golfers.
Reconcile IDs and inspect raw availability flags. Next retrieve the **complete
2018–19 PGA season** (across both calendar years) before comparing a
season-level SG: Putting and driving-distance calculation against the
screenshot-backed Spieth card (+0.862 and 295.2 yards). Exact equality is
plausible only if definitions, included events, and denominators match. Log
differences rather than overwriting either source. Validate unique
event/player/round keys, score and SG consistency, missingness, season
boundaries, and cohort coverage before a full 2018–2026 tour-year download.
Integrate the approved source into the existing Ruby materializer/validator;
the current seven-row Spieth pilot must remain distinguished by source and
confidence.

## Current blockers and next decision

- No authorized PGA TOUR bulk access or Data Golf archive subscription/key is
  available in this workspace. No bulk statistical coverage was added.
- The Data Golf license needs confirmation for the intended academic/public
  outputs and source-row retention. This is a data-use question, not merely a
  payment decision.
- Neither route yet establishes a licensed, cross-tour *putting average* with
  common numerator/denominator; SG: Putting is a distinct measure.
- The repo's major-panel missingness and incomplete LIV debut inventory still
  prevent an analysis-ready causal panel even after season stats are added.

If permission and budget are available, request Data Golf's written guidance
and an annual archive subscription, then implement the bounded pilot. If not,
limit the immediate work to manual, attributed PGA season-card checks for a
small pre-specified sample and continue the open major-field/debut audit.
