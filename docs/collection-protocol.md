# Collection protocol

## Source order and scope

Collect full leaderboard fields, not only finishers, from official PGA Tour,
DP World Tour, LIV, and major-championship sources. ESPN is a documented
fallback; public Data Golf pages supplement source-reported SG only. Record the
event-specific URL, source ID, and UTC retrieval time on every imported row.

The final dataset should load all actual LIV starters from the league's
inception onward, including substitutes. A player's treatment date is their
first **verified actual** LIV start, not an announcement, contract, roster
date, or merely the earliest appearance in a sparse extract. The current
pilot has complete consecutive fields only for the first three LIV events;
debut dates outside that prefix remain unverified. A later actual start still
proves the golfer was treated by that date.

## Import workflow

1. Add/verify the event inventory in `data/staging/events.csv`; retain actual
   dates, course, tour season, format, and cut rule.
2. Download the declared public page with `fetch_sources.py`, then retain its
   filename and checksum in the fetch log. The cache is deliberately ignored by
   Git because source terms and page content can change.
3. Transcribe or parse observed source fields into staging tables. Preserve the
   original finish text and source SG values.
4. Mark a round's group complete only after reconciling it to the leaderboard's
   full scoring field. For multi-course events, use the published course name.
5. Run `ruby --disable-gems scripts/materialize_observed_data.rb` and
   `ruby --disable-gems scripts/validate_observed_data.rb` and resolve every
   error before analysis. The older Python scripts are not the pilot's
   authoritative reproduction path.

## Required edge-case handling

- A missed cut is distinct from a withdrawal, disqualification, and no-cut event.
- Count only completed rounds. Never fill an incomplete round with a score.
- Exclude team, match-play, and modified scoring from calculated SG.
- Preserve playoffs in original finish text; do not add playoff holes to round totals.
- For shortened events, retain the actual round count and cut rule.
- Do not calculate cross-tour ability from raw field-relative SG.

## Inventory reconciliation

`major_events.csv` deliberately contains 35 played majors from 2018--2026:
four per year except the cancelled 2020 Open Championship. Before release,
reconcile every tour-year inventory and its field count against an official
schedule and leaderboard, then record unresolved rows in the coverage report.
