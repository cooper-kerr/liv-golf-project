#!/usr/bin/env python3
"""Build pre-major profiles with no future information leakage."""
from __future__ import annotations

import csv
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NORM, STAGING = ROOT / "data/normalized", ROOT / "data/staging"


def read(path: Path):
    with path.open(newline="", encoding="utf-8") as f: return list(csv.DictReader(f))


def mean(values): return f"{sum(values) / len(values):.6f}" if values else ""


def main() -> None:
    events = {r["event_id"]: r for r in read(NORM / "events.csv")}
    results = read(NORM / "player_event_results_normalized.csv")
    rounds = read(NORM / "player_round_results_normalized.csv")
    liv = read(STAGING / "liv_appearances.csv")
    rounds_by_result = {}
    for round_row in rounds:
        rounds_by_result.setdefault((round_row["event_id"], round_row["player_id"]), []).append(round_row)
    liv_start = {}
    for row in liv:
        previous = liv_start.get(row["player_id"])
        if previous is None or row["start_date"] < previous: liv_start[row["player_id"]] = row["start_date"]
    players = sorted({r["player_id"] for r in results} | set(liv_start))
    majors = [e for e in events.values() if e["competition_group"] == "major"]
    output = []
    for major in majors:
        cutoff = datetime.strptime(major["start_date"], "%Y-%m-%d").date()
        for player in players:
            historic = [r for r in results if r["player_id"] == player and r["start_status"] == "started" and events[r["event_id"]]["end_date"] < major["start_date"]]
            for window, eligible in (("annual", [r for r in historic if events[r["event_id"]]["start_date"][:4] == major["season"]]), ("trailing_365", [r for r in historic if datetime.strptime(events[r["event_id"]]["end_date"], "%Y-%m-%d").date() >= cutoff - timedelta(days=365)])):
                for tour in ("all", "pga", "dpwt", "liv", "major"):
                    chosen = eligible if tour == "all" else [r for r in eligible if events[r["event_id"]]["competition_group"] == tour]
                    completed_rounds = [rr for r in chosen for rr in rounds_by_result.get((r["event_id"], player), []) if rr["completion_status"] == "completed"]
                    sgs = [float(rr["field_relative_sg"]) for rr in completed_rounds if rr["field_relative_sg"]]
                    distances = [float(rr["driving_distance_yards"]) for rr in completed_rounds if rr["driving_distance_yards"]]
                    classified = [float(r["finishing_percentile"]) for r in chosen if r["finishing_percentile"]]
                    made = sum(r["cut_outcome"] == "made_cut" for r in chosen if r["cut_outcome"] in {"made_cut", "missed_cut"})
                    cut_denominator = sum(r["cut_outcome"] in {"made_cut", "missed_cut"} for r in chosen)
                    output.append({"player_id": player, "event_id": major["event_id"], "profile_as_of": major["start_date"], "profile_window": window, "profile_tour": tour, "treated_by_as_of": "1" if player in liv_start and liv_start[player] < major["start_date"] else "0", "first_liv_start_date": liv_start.get(player, ""), "starts": len(chosen), "rounds_completed": len(completed_rounds), "cut_rate": f"{made/cut_denominator:.6f}" if cut_denominator else "", "average_field_relative_sg": mean(sgs), "average_finishing_percentile": mean(classified), "average_driving_distance_yards": mean(distances), "driving_distance_round_coverage": f"{len(distances)/len(completed_rounds):.6f}" if completed_rounds else "", "sg_round_coverage": f"{len(sgs)/len(completed_rounds):.6f}" if completed_rounds else ""})
    fields = list(output[0]) if output else ["player_id", "event_id", "profile_as_of", "profile_window", "profile_tour", "treated_by_as_of", "first_liv_start_date", "starts", "rounds_completed", "cut_rate", "average_field_relative_sg", "average_finishing_percentile", "average_driving_distance_yards", "driving_distance_round_coverage", "sg_round_coverage"]
    with (NORM / "profile_snapshots.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields); writer.writeheader(); writer.writerows(output)
    print(f"Built {len(output)} profile snapshots.")


if __name__ == "__main__": main()
