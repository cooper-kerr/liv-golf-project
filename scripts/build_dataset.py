#!/usr/bin/env python3
"""Validate staging data and derive event/round outcomes without imputation."""
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from datetime import date, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STAGING, REFERENCE, OUTPUT, REPORTS = (ROOT / "data/staging", ROOT / "data/reference", ROOT / "data/normalized", ROOT / "reports")
VALID_FORMATS = {"stroke_play", "match_play", "team", "modified"}
VALID_CUTS = {"after_36_holes", "none", "other", "unknown"}
VALID_COMPLETION = {"completed", "withdrawn", "disqualified", "did_not_start", "incomplete"}
VALID_START = {"started", "did_not_start"}
VALID_OUTCOMES = {"made_cut", "missed_cut", "not_applicable", "withdrawn", "disqualified", "unknown"}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        out = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        out.writeheader(); out.writerows(rows)


def error(message: str) -> None:
    raise ValueError(message)


def number(value: str) -> float | None:
    return float(value) if value not in (None, "") else None


def check_keys(rows: list[dict], fields: tuple[str, ...], label: str) -> None:
    seen = set()
    for n, row in enumerate(rows, 2):
        key = tuple(row.get(field, "").strip() for field in fields)
        if not all(key): error(f"{label} line {n}: blank key {fields}")
        if key in seen: error(f"{label} line {n}: duplicate key {key}")
        seen.add(key)


def parse_date(value: str, label: str) -> date:
    try: return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError: error(f"{label}: invalid ISO date {value!r}")


def main() -> None:
    events = read_csv(REFERENCE / "major_events.csv") + read_csv(STAGING / "events.csv")
    players = read_csv(STAGING / "players.csv")
    rounds = read_csv(STAGING / "player_round_results.csv")
    reported = read_csv(STAGING / "player_event_results.csv")
    season_stats = read_csv(STAGING / "player_season_statistics.csv")
    liv = read_csv(STAGING / "liv_appearances.csv")
    check_keys(events, ("event_id",), "events"); check_keys(players, ("player_id",), "players")
    check_keys(rounds, ("event_id", "player_id", "round_number"), "rounds")
    check_keys(reported, ("event_id", "player_id"), "event results")
    event_by_id = {r["event_id"]: r for r in events}; player_ids = {r["player_id"] for r in players}
    for event in events:
        parse_date(event["start_date"], f"event {event['event_id']}")
        if event["format"] not in VALID_FORMATS: error(f"event {event['event_id']}: invalid format")
        if event["cut_rule"] not in VALID_CUTS: error(f"event {event['event_id']}: invalid cut rule")
    for row in rounds:
        if row["event_id"] not in event_by_id or row["player_id"] not in player_ids: error(f"round has unknown event/player: {row}")
        if int(row["round_number"]) not in (1, 2, 3, 4): error(f"round has invalid round_number: {row}")
        if row["completion_status"] not in VALID_COMPLETION: error(f"round has invalid status: {row}")
        if row["is_scoring_group_complete"] not in {"yes", "no"}: error("is_scoring_group_complete must be yes/no")
        if row["completion_status"] == "completed" and number(row["strokes"]) is None: error("completed round needs strokes")
    for row in reported:
        if row["event_id"] not in event_by_id or row["player_id"] not in player_ids: error(f"event result has unknown event/player: {row}")
        if row["start_status"] not in VALID_START or row["cut_outcome"] not in VALID_OUTCOMES or row["completion_status"] not in VALID_COMPLETION: error(f"invalid event status: {row}")
        if event_by_id[row["event_id"]]["cut_rule"] == "none" and row["cut_outcome"] in {"made_cut", "missed_cut"}: error(f"no-cut event incorrectly has cut result: {row}")
    for row in season_stats:
        if row["player_id"] not in player_ids: error(f"season statistic has unknown player: {row}")
        if number(row["value"]) is None or not row["metric"] or not row["unit"] or not row["measurement_definition"]: error(f"season statistic is missing required measurement metadata: {row}")
    for row in liv:
        if row["player_id"] not in player_ids or row["event_id"] not in event_by_id: error(f"LIV appearance has unknown event/player: {row}")
        if event_by_id[row["event_id"]]["competition_group"] != "liv": error(f"LIV appearance is not a LIV event: {row}")
        parse_date(row["start_date"], "LIV appearance")

    # A group must be both declared complete and contain only completed stroke scores.
    groups: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    for row in rounds: groups[(row["event_id"], row["round_number"], row["course_name"])].append(row)
    sg_by_round: dict[tuple[str, str, str], float] = {}
    normalized_rounds = []
    for key, rows in groups.items():
        event = event_by_id[key[0]]
        eligible = event["format"] == "stroke_play" and rows and all(r["is_scoring_group_complete"] == "yes" and r["completion_status"] == "completed" and number(r["strokes"]) is not None for r in rows)
        mean = sum(number(r["strokes"]) for r in rows) / len(rows) if eligible else None
        for row in rows:
            out = dict(row); out["field_relative_sg"] = "" if mean is None else f"{mean - number(row['strokes']):.6f}"
            normalized_rounds.append(out)
            if mean is not None: sg_by_round[(row["event_id"], row["player_id"], row["round_number"])] = mean - number(row["strokes"])
        if mean is not None and abs(sum(sg_by_round[(r["event_id"], r["player_id"], r["round_number"])] for r in rows)) > 1e-8:
            error(f"calculated SG does not sum to zero for scoring group {key}")

    result_by_key = {(r["event_id"], r["player_id"]): dict(r) for r in reported}
    classified: dict[str, list[int]] = defaultdict(list)
    for row in reported:
        if row["completion_status"] == "completed" and row["finish_position"]:
            classified[row["event_id"]].append(int(row["finish_position"]))
    normalized_results = []
    for key, row in result_by_key.items():
        event_rounds = [r for r in rounds if (r["event_id"], r["player_id"]) == key and r["completion_status"] == "completed"]
        sgs = [sg_by_round[(r["event_id"], r["player_id"], r["round_number"])] for r in event_rounds if (r["event_id"], r["player_id"], r["round_number"]) in sg_by_round]
        first_two = [sg_by_round[(r["event_id"], r["player_id"], r["round_number"])] for r in event_rounds if r["round_number"] in {"1", "2"} and (r["event_id"], r["player_id"], r["round_number"]) in sg_by_round]
        out = dict(row); out["derived_rounds_completed"] = str(len(event_rounds)); out["average_field_relative_sg"] = f"{sum(sgs)/len(sgs):.6f}" if sgs else ""; out["first_two_round_field_relative_sg"] = f"{sum(first_two)/len(first_two):.6f}" if first_two else ""
        n = len(classified[key[0]]); position = int(row["finish_position"]) if row["finish_position"] else None
        out["classified_finishers"] = str(n); out["finishing_percentile"] = f"{(n-position)/(n-1):.6f}" if position is not None and n > 1 else ""
        normalized_results.append(out)

    # Primary cohort is determined only by an observed major start before LIV launch.
    launch = date(2022, 6, 9)
    cohort = {r["player_id"] for r in reported if r["start_status"] == "started" and event_by_id[r["event_id"]]["competition_group"] == "major" and parse_date(event_by_id[r["event_id"]]["start_date"], "event") < launch}
    panels = []
    for player_id in sorted(cohort):
        for event in events:
            if event["competition_group"] != "major": continue
            observed = result_by_key.get((event["event_id"], player_id))
            participation = "1" if observed and observed["start_status"] == "started" else ("0" if observed else "unknown")
            panels.append({"player_id": player_id, "event_id": event["event_id"], "participated": participation, "performance_observed": "1" if observed and observed["start_status"] == "started" else "0"})

    OUTPUT.mkdir(parents=True, exist_ok=True); REPORTS.mkdir(parents=True, exist_ok=True)
    write_csv(OUTPUT / "events.csv", events, list(events[0]) if events else [])
    write_csv(OUTPUT / "player_round_results_normalized.csv", normalized_rounds, list(rounds[0]) + ["field_relative_sg"] if rounds else [])
    write_csv(OUTPUT / "player_event_results_normalized.csv", normalized_results, list(reported[0]) + ["derived_rounds_completed", "average_field_relative_sg", "first_two_round_field_relative_sg", "classified_finishers", "finishing_percentile"] if reported else [])
    write_csv(OUTPUT / "major_participation_panel.csv", panels, ["player_id", "event_id", "participated", "performance_observed"])
    def treatment_group(player_id: str, when: str) -> str:
        starts = [parse_date(r["start_date"], "LIV appearance") for r in liv if r["player_id"] == player_id]
        return "treated" if starts and min(starts) <= parse_date(when, "event") else "not_yet_treated"
    coverage = {
        "events_by_group_year": dict(Counter(f"{e['competition_group']}:{e['season']}" for e in events)),
        "round_rows_by_group_year": dict(Counter(f"{event_by_id[r['event_id']]['competition_group']}:{event_by_id[r['event_id']]['season']}" for r in rounds)),
        "event_result_rows_by_group_year": dict(Counter(f"{event_by_id[r['event_id']]['competition_group']}:{event_by_id[r['event_id']]['season']}" for r in reported)),
        "round_metric_coverage": {metric: sum(bool(r.get(column)) for r in rounds) for metric, column in {"strokes": "strokes", "calculated_field_relative_sg": "strokes", "source_overall_sg": "source_overall_sg", "source_sg_off_tee": "source_sg_off_tee", "source_sg_approach": "source_sg_approach", "source_sg_around_green": "source_sg_around_green", "source_sg_putting": "source_sg_putting", "driving_distance_yards": "driving_distance_yards"}.items()},
        "season_stat_rows_by_metric_tour_year": dict(Counter(f"{r['metric']}:{r['tour']}:{r['season']}" for r in season_stats)),
        "event_result_rows_by_treatment": dict(Counter(treatment_group(r["player_id"], event_by_id[r["event_id"]]["start_date"]) for r in reported)),
        "rounds_with_calculated_sg": len(sg_by_round), "primary_major_cohort_players": len(cohort), "unresolved_major_panel_cells": sum(p["participated"] == "unknown" for p in panels),
    }
    (REPORTS / "coverage_report.json").write_text(json.dumps(coverage, default=dict, indent=2, sort_keys=True) + "\n")
    print(f"Built {len(events)} events, {len(normalized_rounds)} rounds, {len(normalized_results)} event results, and {len(panels)} major panel rows.")


if __name__ == "__main__": main()
