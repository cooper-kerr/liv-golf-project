#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'date'
require 'json'

ROOT = File.expand_path('..', __dir__)
def rows(path)
  CSV.read(File.join(ROOT, path), headers: true).map(&:to_h)
end

def check(condition, message)
  raise message unless condition
end

sources = rows('data/reference/observed_event_sources.csv')
observed = rows('data/staging/observed_leaderboard_rows.csv')
events = rows('data/normalized/events.csv')
rounds = rows('data/normalized/player_round_results_normalized.csv')
results = rows('data/normalized/player_event_results_normalized.csv')
panel = rows('data/normalized/major_participation_panel.csv')
flat_panel = rows('data/normalized/experiment_ready_major_panel.csv')
profiles = rows('data/normalized/profile_snapshots.csv')
debuts = rows('data/normalized/verified_liv_debuts.csv')
season_stats = rows('data/staging/player_season_statistics.csv')
players = rows('data/staging/players.csv')
coverage = JSON.parse(File.read(File.join(ROOT, 'reports/coverage_report.json')))

check(sources.length >= 30, 'Expanded sourced event set missing')
check(observed.length == results.length, 'Observed/result count mismatch')
check(results.length == coverage['player_event_rows'] && rounds.length == coverage['player_round_rows'], 'Coverage row counts disagree')
check(results.map { |r| [r['event_id'], r['player_id']] }.uniq.length == results.length, 'Duplicate result key')
check(rounds.map { |r| [r['event_id'], r['player_id'], r['round_number']] }.uniq.length == rounds.length, 'Duplicate round key')
check(events.map { |e| e['event_id'] }.uniq.length == events.length, 'Duplicate event key')
check(debuts.map { |r| r['player_id'] }.uniq.length == debuts.length, 'Duplicate verified debut')
check(season_stats.map { |r| [r['player_id'], r['season'], r['tour'], r['metric']] }.uniq.length == season_stats.length,
      'Duplicate player-season-tour-metric key')
player_ids = players.map { |r| r['player_id'] }
season_stats.each do |row|
  check(player_ids.include?(row['player_id']), "Unknown season-stat player: #{row['player_id']}")
  %w[value unit measurement_definition observation_start observation_end source_id source_url retrieved_at].each do |field|
    check(!row[field].to_s.empty?, "Missing season-stat #{field}: #{row['player_id']}/#{row['metric']}")
  end
  check(Date.iso8601(row['observation_start']) <= Date.iso8601(row['observation_end']),
        "Inverted season-stat observation bounds: #{row['player_id']}/#{row['metric']}")
  Date.iso8601(row['retrieved_at'])
  check(Float(row['value']).finite?, "Nonfinite season-stat value: #{row['player_id']}/#{row['metric']}")
  if %w[scrambling_pct greens_in_regulation_pct].include?(row['metric'])
    fraction = row['measurement_definition'].match(/(\d+)\/(\d+)/)
    if fraction
      check(fraction[2].to_i.positive? &&
            (100.0 * fraction[1].to_i / fraction[2].to_i - row['value'].to_f).abs <= 0.011,
            "Season percentage disagrees with published counts: #{row['player_id']}/#{row['metric']}")
    end
  elsif row['metric'] == 'putting_average_per_hole'
    fraction = row['measurement_definition'].match(/(\d+) total putts \/ (\d+) holes/)
    check(fraction && fraction[2].to_i.positive? &&
          (fraction[1].to_f / fraction[2].to_i - row['value'].to_f).abs <= 0.0051,
          "LIV putting average disagrees with total putts: #{row['player_id']}")
  elsif row['metric'] == 'putting_average_on_gir'
    fraction = row['measurement_definition'].match(/(\d+) GIR putts \/ (\d+) greens hit/)
    if fraction
      check(fraction[2].to_i.positive? &&
            (fraction[1].to_f / fraction[2].to_i - row['value'].to_f).abs <= 0.0006,
            "PGA putting average disagrees with GIR putts: #{row['player_id']}")
    end
  end
end
check(coverage['season_stat_rows'] == season_stats.length, 'Season-stat coverage count mismatch')
observed.each do |row|
  scores = (1..4).map { |number| row["r#{number}_strokes"] }.reject { |value| value.to_s.empty? }.map(&:to_i)
  next if row['finish_text'] == 'WD'
  check(scores.sum == row['total_strokes'].to_i, "Published total does not equal rounds: #{row['event_id']}/#{row['source_player_name']}")
  check(scores.all? { |score| score.between?(55, 100) }, "Implausible score: #{row['event_id']}/#{row['source_player_name']}")
end

sources.each do |source|
  subset = results.select { |r| r['event_id'] == source['event_id'] }
  check(subset.count { |r| r['completion_status'] == 'completed' } == source['observed_final_results'].to_i,
        "Finisher count differs from source: #{source['event_id']}")
  next unless source['field_verified_complete'] == 'yes'
  check(subset.length == source['expected_starters'].to_i, "Field size differs from source: #{source['event_id']}")
end

rounds.group_by { |r| [r['event_id'], r['round_number'], r['course_name']] }.each do |key, group|
  values = group.map { |r| r['field_relative_sg'] }
  next if values.all?(&:empty?)
  check(values.none?(&:empty?), "Partial SG group: #{key}")
  check(group.all? { |r| r['is_scoring_group_complete'] == 'yes' }, "Unverified SG group: #{key}")
  check(values.sum(&:to_f).abs <= group.length * 0.000001, "SG group not zero-centered: #{key}")
end

cut_rows = results.select { |r| r['cut_outcome'] == 'missed_cut' }
{ 'major-2018-masters' => 34, 'major-2024-masters' => 29,
  'major-2024-pga' => 75, 'major-2024-us-open' => 82,
  'major-2024-open' => 74, 'major-2025-masters' => 42,
  'major-2025-pga' => 81, 'major-2025-us-open' => 88,
  'major-2025-open' => 86, 'major-2026-masters' => 37 }.each do |event_id, expected|
  check(cut_rows.count { |r| r['event_id'] == event_id } == expected, "Cut count incorrect: #{event_id}")
end
check(cut_rows.all? { |r| r['rounds_completed'] == '2' && r['finishing_percentile'].empty? }, 'Missed cut has invented finish')
check(results.select { |r| r['completion_status'] == 'withdrawn' }.length == 11, 'Withdrawal count incorrect')
check(results.select { |r| r['cut_outcome'] == 'not_applicable' }.all? do |r|
  events.find { |e| e['event_id'] == r['event_id'] }['cut_rule'] == 'none'
end, 'No-cut status mismatch')
check(rounds.select { |r| r['event_id'] == 'liv-2026-riyadh' }.length == 228, '2026 LIV 72-hole format missing')

major_by_id = events.select { |e| e['competition_group'] == 'major' }.to_h { |e| [e['event_id'], e] }
check(major_by_id.length == 35, 'Played major inventory incorrect')
%w[2024 2025].each do |year|
  check(sources.count { |s| s['competition_group'] == 'major' && s['start_date'].start_with?(year) && s['field_verified_complete'] == 'yes' } == 4,
        "Incomplete major field in #{year}")
end
check(coverage['unsourced_major_events'].length == 35 - sources.count { |s| s['competition_group'] == 'major' }, 'Unsourced majors not reported')
check(coverage['metric_observations']['field_relative_sg'] == rounds.count { |r| !r['field_relative_sg'].empty? }, 'SG coverage count mismatch')
check(panel.length == coverage['major_cohort_players_observed'] * 35, 'Panel size mismatch')
check(flat_panel.length == panel.length, 'Flat experiment panel size mismatch')
check(flat_panel.map { |r| [r['player_id'], r['event_id']] }.uniq.length == flat_panel.length, 'Duplicate flat panel key')
panel.each do |row|
  source = sources.find { |s| s['event_id'] == row['event_id'] }
  check(!row['participated'].empty?, 'Blank major participation')
  check(row['participated'] != '0' || source && source['field_verified_complete'] == 'yes', 'Unverified participation zero')
  check(row['participated'] == '1' || row['finish_position'].to_s.empty?, 'Performance assigned to nonparticipant')
end
flat_panel.each do |row|
  check(row['pga_annual_observed_starts'] && row['liv_trailing_365_observed_rounds'], 'Missing wide profile columns')
end

event_by_id = events.to_h { |e| [e['event_id'], e] }
result_by_player = results.group_by { |r| r['player_id'] }
profiles.each do |profile|
  as_of = Date.iso8601(profile['profile_as_of'])
  from = profile['profile_window'] == 'annual' ? Date.new(as_of.year, 1, 1) : as_of - 365
  expected = result_by_player.fetch(profile['player_id'], []).count do |result|
    event = event_by_id.fetch(result['event_id'])
    ended = Date.iso8601(event['end_date'])
    result['start_status'] == 'started' && event['competition_group'] == profile['profile_tour'] &&
      ended >= from && ended < as_of
  end
  check(profile['starts'].to_i == expected, "Profile look-ahead or starts mismatch: #{profile['player_id']}/#{profile['event_id']}")
end
annual_major_profiles = profiles.select { |r| r['profile_window'] == 'annual' && r['profile_tour'] == 'major' }
treatment_by_key = annual_major_profiles.to_h { |r| [[r['player_id'], r['event_id']], r['treatment_status']] }
panel.each do |row|
  check(row['treatment_status'] == treatment_by_key.fetch([row['player_id'], row['event_id']]), 'Panel/profile treatment mismatch')
end

puts "Validated #{sources.length} source events, #{results.length} results, #{rounds.length} rounds, #{panel.length} major-panel cells, and #{profiles.length} tour-window profiles."
