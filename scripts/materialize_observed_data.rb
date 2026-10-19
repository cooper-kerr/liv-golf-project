#!/usr/bin/env ruby
# frozen_string_literal: true

# Build a conservative, source-traceable experiment pilot from curated published
# leaderboard rows. Ruby 2.6 standard library only; run with --disable-gems on
# macOS installations where RubyGems directories are sandboxed.
require 'csv'
require 'date'
require 'json'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
REF = File.join(ROOT, 'data', 'reference')
STAGE = File.join(ROOT, 'data', 'staging')
OUT = File.join(ROOT, 'data', 'normalized')
REPORTS = File.join(ROOT, 'reports')
LAUNCH = Date.iso8601('2022-06-09')
FileUtils.mkdir_p([STAGE, OUT, REPORTS])

def read_csv(path)
  CSV.read(path, headers: true).map(&:to_h)
end

def write_csv(path, fields, rows)
  CSV.open(path, 'w', write_headers: true, headers: fields) do |csv|
    rows.each { |row| csv << fields.map { |field| row[field] } }
  end
end

def fail_if(condition, message)
  raise message if condition
end

def ascii(text)
  text.unicode_normalize(:nfkd).encode('ASCII', invalid: :replace, undef: :replace, replace: '')
end

def canonical_name(name)
  cleaned = ascii(name.sub(/ \(a\)\z/, '').sub(/ \([^)]+\)\z/, '')).strip
  aliases = {
    'Matt Fitzpatrick' => 'Matthew Fitzpatrick',
    'Cam Davis' => 'Cameron Davis',
    'Graeme Mcdowell' => 'Graeme McDowell',
    'Bryson Dechambeau' => 'Bryson DeChambeau',
    'Jj Spaun' => 'JJ Spaun',
    'J.J. Spaun' => 'JJ Spaun',
    'J. J. Spaun' => 'JJ Spaun',
    'Jc Ritchie' => 'JC Ritchie',
    'Charles Howell Iii' => 'Charles Howell III',
    'Harold Varner Iii' => 'Harold Varner III',
    'Rory Mcilroy' => 'Rory McIlroy',
    'Robert Macintyre' => 'Robert MacIntyre',
    'Jose Maria Olazabal' => 'Jose Maria Olazabal',
    'Hao Tong Li' => 'Haotong Li',
    'Li Haotong' => 'Haotong Li',
    'Lee Kyoung-hoon' => 'K.H. Lee',
    'Pan Cheng-tsung' => 'C.T. Pan',
    'Im Sung-jae' => 'Sungjae Im',
    'Kim Si-woo' => 'Si Woo Kim',
    'An Byeong-hun' => 'Byeong Hun An',
    'J. T. Poston' => 'J.T. Poston'
  }
  aliases.fetch(cleaned, cleaned)
end

def player_id(name)
  ascii(canonical_name(name)).downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
end

def field_source(source, field)
  fail_if(source[field].to_s.empty?, "Missing #{field} for #{source['event_id']}")
  source[field]
end

source_rows = read_csv(File.join(REF, 'observed_event_sources.csv'))
observed = read_csv(File.join(STAGE, 'observed_leaderboard_rows.csv'))
season_stats = read_csv(File.join(STAGE, 'player_season_statistics.csv'))
sources = source_rows.to_h { |row| [row.fetch('event_id'), row] }
fail_if(sources.length != source_rows.length, 'Duplicate event source IDs')
fail_if(source_rows.empty?, 'No sourced events to materialize')
write_csv(File.join(REF, 'source_requests.csv'), %w[request_id event_id source_id url expected_kind notes],
          source_rows.map do |row|
            { 'request_id' => row['event_id'], 'event_id' => row['event_id'],
              'source_id' => row['source_id'], 'url' => row['source_url'],
              'expected_kind' => row['source_url'].end_with?('.pdf') ? 'pdf' : 'html',
              'notes' => row['coverage_note'] }
          end)

major_events = read_csv(File.join(REF, 'major_events.csv'))
event_fields = CSV.read(File.join(REF, 'major_events.csv'), headers: true).headers + ['tour_season', 'field_verified_complete']
events = major_events.map do |event|
  source = sources[event['event_id']]
  event.merge(
    'tour_season' => event['season'],
    'field_verified_complete' => source ? source['field_verified_complete'] : '',
    'source_id' => source ? source['source_id'] : event['source_id'],
    'source_url' => source ? source['source_url'] : event['source_url']
  )
end
name_by_event = {
  'pga-2018-wells-fargo' => 'Wells Fargo Championship',
  'pga-2022-sentry' => 'Sentry Tournament of Champions',
  'liv-2022-london' => 'LIV Golf Invitational London',
  'liv-2022-portland' => 'LIV Golf Invitational Portland',
  'liv-2022-bedminster' => 'LIV Golf Invitational Bedminster',
  'liv-2022-jeddah' => 'LIV Golf Invitational Jeddah',
  'dpwt-2022-tour-championship' => 'DP World Tour Championship',
  'dpwt-2023-czech-masters' => 'D+D Real Czech Masters',
  'pga-2024-sentry' => 'The Sentry',
  'liv-2024-las-vegas' => 'LIV Golf Las Vegas',
  'liv-2024-singapore' => 'LIV Golf Singapore',
  'liv-2025-adelaide' => 'LIV Golf Adelaide',
  'pga-2025-rbc-heritage' => 'RBC Heritage',
  'liv-2026-riyadh' => 'LIV Golf Riyadh',
  'pga-2026-wyndham' => 'Wyndham Championship',
  'dpwt-2026-bmw-pga' => 'BMW PGA Championship'
}
source_rows.each do |source|
  next if source['competition_group'] == 'major'
  id = source['event_id']
  fail_if(!name_by_event.key?(id), "Missing event name: #{id}")
  tour = { 'pga' => 'PGA Tour', 'dpwt' => 'DP World Tour', 'liv' => 'LIV Golf' }.fetch(source['competition_group'])
  events << {
    'event_id' => id, 'event_name' => name_by_event[id], 'season' => source['end_date'][0, 4],
    'tour' => tour, 'competition_group' => source['competition_group'],
    'start_date' => source['start_date'], 'end_date' => source['end_date'],
    'course_name' => source['course_name'], 'city' => source['city'], 'country' => source['country'],
    'format' => 'stroke_play', 'cut_rule' => source['cut_rule'], 'event_status' => 'played',
    'source_id' => source['source_id'], 'source_url' => source['source_url'],
    'tour_season' => source['tour_season'], 'field_verified_complete' => source['field_verified_complete']
  }
end
events_by_id = events.to_h { |event| [event['event_id'], event] }
fail_if(events.length != events_by_id.length, 'Duplicate event IDs after major deduplication')
source_rows.each do |source|
  event = events_by_id.fetch(source['event_id'])
  fail_if(event['start_date'] != source['start_date'] || event['end_date'] != source['end_date'], "Source/inventory date mismatch: #{source['event_id']}")
end
write_csv(File.join(STAGE, 'events.csv'), event_fields, events.reject { |event| event['competition_group'] == 'major' })
write_csv(File.join(OUT, 'events.csv'), event_fields, events)

players = {}
aliases = {}
rounds = []
results = []
liv_appearances = []
seen_results = {}
observed.each do |row|
  event_id = row.fetch('event_id')
  source = sources.fetch(event_id) { raise "Missing source metadata: #{event_id}" }
  event = events_by_id.fetch(event_id)
  name = row.fetch('source_player_name')
  id = player_id(name)
  fail_if(id.empty?, "Unusable player name: #{name}")
  fail_if(players[id] && players[id]['canonical_name'] != canonical_name(name),
          "Player slug collision requiring alias review: #{id} / #{name}")
  key = [event_id, id]
  fail_if(seen_results[key], "Duplicate player/event: #{key.join('/')}")
  seen_results[key] = true
  players[id] ||= {
    'player_id' => id, 'canonical_name' => canonical_name(name), 'country' => '', 'birth_date' => '',
    'source_id' => source['source_id'], 'source_player_id' => '', 'source_url' => source['source_url']
  }
  aliases[[name, source['source_id']]] ||= {
    'alias' => name, 'player_id' => id, 'source_id' => source['source_id'],
    'source_player_id' => '', 'notes' => ''
  }
  scores = (1..4).map { |number| row["r#{number}_strokes"] }.reject { |value| value.to_s.empty? }.map(&:to_i)
  finish = row.fetch('finish_text')
  classified = finish.match?(/\A(?:[PT]?\d+)\z/)
  fail_if(!classified && !%w[Cut WD DQ].include?(finish), "Unknown finish status: #{finish}")
  fail_if(classified && (scores.empty? || scores.sum != row['total_strokes'].to_i), "Round total mismatch: #{event_id}/#{name}")
  fail_if(finish == 'Cut' && scores.length != 2, "Cut player does not have two complete rounds: #{event_id}/#{name}")
  fail_if(classified && scores.length != (event['competition_group'] == 'liv' && event['season'] != '2026' ? 3 : 4), "Unexpected round count: #{event_id}/#{name}")
  status = if finish == 'WD' then 'withdrawn'
           elsif finish == 'DQ' then 'disqualified'
           elsif finish == 'Cut' then 'missed_cut'
           else 'completed' end
  cut = if finish == 'Cut' then 'missed_cut'
        elsif finish == 'WD' then 'withdrawn'
        elsif finish == 'DQ' then 'disqualified'
        elsif event['cut_rule'] == 'none' then 'not_applicable'
        else 'made_cut' end
  position = classified ? finish.delete('TP').to_i : nil
  provenance = { 'source_id' => source['source_id'], 'source_url' => source['source_url'], 'retrieved_at' => source['retrieved_at_utc'] }
  result = {
    'event_id' => event_id, 'player_id' => id,
    'start_status' => finish == 'WD' && scores.empty? ? 'unknown' : 'started', 'cut_outcome' => cut,
    'completion_status' => status, 'finish_text' => finish, 'finish_position' => position,
    'rounds_completed' => scores.length
  }.merge(provenance)
  results << result
  scores.each_with_index do |score, index|
    rounds << {
      'event_id' => event_id, 'player_id' => id, 'round_number' => index + 1,
      'course_name' => source['course_name'], 'round_date' => '', 'strokes' => score,
      'score_to_par' => '', 'completion_status' => 'completed',
      'is_scoring_group_complete' => source['field_verified_complete'],
      'source_overall_sg' => '', 'source_sg_off_tee' => '', 'source_sg_approach' => '',
      'source_sg_around_green' => '', 'source_sg_putting' => '',
      'driving_distance_yards' => '', 'distance_measurement' => ''
    }.merge(provenance)
  end
  if event['competition_group'] == 'liv' && result['start_status'] == 'started'
    liv_appearances << {
      'player_id' => id, 'event_id' => event_id, 'start_date' => source['start_date'],
      'appearance_role' => 'unknown'
    }.merge(provenance)
  end
end

source_rows.each do |source|
  event_results = results.select { |result| result['event_id'] == source['event_id'] }
  classified = event_results.count { |result| result['completion_status'] == 'completed' }
  fail_if(classified != source['observed_final_results'].to_i, "Finisher count mismatch: #{source['event_id']}")
  if source['field_verified_complete'] == 'yes'
    fail_if(event_results.length != source['expected_starters'].to_i, "Full-field count mismatch: #{source['event_id']}")
  end
end

write_csv(File.join(STAGE, 'players.csv'), %w[player_id canonical_name country birth_date source_id source_player_id source_url], players.values.sort_by { |row| row['player_id'] })
write_csv(File.join(STAGE, 'player_aliases.csv'), %w[alias player_id source_id source_player_id notes], aliases.values.sort_by { |row| [row['player_id'], row['alias']] })
round_fields = %w[event_id player_id round_number course_name round_date strokes score_to_par completion_status is_scoring_group_complete source_overall_sg source_sg_off_tee source_sg_approach source_sg_around_green source_sg_putting driving_distance_yards distance_measurement source_id source_url retrieved_at]
result_fields = %w[event_id player_id start_status cut_outcome completion_status finish_text finish_position rounds_completed source_id source_url retrieved_at]
write_csv(File.join(STAGE, 'player_round_results.csv'), round_fields, rounds)
write_csv(File.join(STAGE, 'player_event_results.csv'), result_fields, results)
write_csv(File.join(STAGE, 'liv_appearances.csv'), %w[player_id event_id start_date appearance_role source_id source_url retrieved_at], liv_appearances)

# London, Portland, and Bedminster are consecutive full 2022 individual LIV
# fields. A first observed appearance in this prefix is therefore a verified
# debut. Later observations cannot establish debut without intervening fields.
debut_events = %w[liv-2022-london liv-2022-portland liv-2022-bedminster]
debut_rows = {}
debut_events.each do |event_id|
  fail_if(sources.fetch(event_id)['field_verified_complete'] != 'yes', "Debut prefix incomplete: #{event_id}")
  liv_appearances.select { |row| row['event_id'] == event_id }.each do |row|
    debut_rows[row['player_id']] ||= {
      'player_id' => row['player_id'], 'first_liv_start_date' => row['start_date'],
      'event_id' => event_id, 'verification_basis' => 'consecutive_complete_fields_from_inaugural_event',
      'source_url' => row['source_url']
    }
  end
end
write_csv(File.join(OUT, 'verified_liv_debuts.csv'), %w[player_id first_liv_start_date event_id verification_basis source_url], debut_rows.values.sort_by { |row| row['player_id'] })

groups = Hash.new { |hash, key| hash[key] = [] }
rounds.each { |row| groups[[row['event_id'], row['round_number'], row['course_name']]] << row }
group_means = {}
groups.each do |key, rows|
  next unless rows.all? { |row| row['is_scoring_group_complete'] == 'yes' && row['completion_status'] == 'completed' }
  group_means[key] = rows.sum { |row| row['strokes'].to_i }.to_f / rows.length
end
normalized_rounds = rounds.map do |row|
  key = [row['event_id'], row['round_number'], row['course_name']]
  mean = group_means[key]
  row.merge('field_relative_sg' => mean ? format('%.6f', mean - row['strokes'].to_i) : '')
end
group_means.each do |key, mean|
  sum_sg = groups[key].sum { |row| mean - row['strokes'].to_i }
  fail_if(sum_sg.abs > 1e-8, "Nonzero group mean SG: #{key}")
end
write_csv(File.join(OUT, 'player_round_results_normalized.csv'), round_fields + ['field_relative_sg'], normalized_rounds)

rounds_by_result = normalized_rounds.group_by { |row| [row['event_id'], row['player_id']] }
classified_by_event = results.select { |row| row['completion_status'] == 'completed' }.group_by { |row| row['event_id'] }
normalized_results = results.map do |row|
  key = [row['event_id'], row['player_id']]
  player_rounds = rounds_by_result.fetch(key, [])
  sg_values = player_rounds.map { |round| round['field_relative_sg'] }.reject(&:empty?).map(&:to_f)
  first_two = player_rounds.select { |round| round['round_number'] <= 2 }.map { |round| round['field_relative_sg'] }.reject(&:empty?).map(&:to_f)
  n = classified_by_event.fetch(row['event_id'], []).length
  percentile = if row['completion_status'] == 'completed' && n > 1
                 format('%.6f', (n - row['finish_position']).to_f / (n - 1))
               else '' end
  row.merge(
    'derived_rounds_completed' => player_rounds.length,
    'sg_rounds_observed' => sg_values.length,
    'average_field_relative_sg' => sg_values.length == player_rounds.length && !sg_values.empty? ? format('%.6f', sg_values.sum / sg_values.length) : '',
    'first_two_round_field_relative_sg' => first_two.length == 2 ? format('%.6f', first_two.sum / 2) : '',
    'classified_finishers' => n, 'finishing_percentile' => percentile
  )
end
normalized_result_fields = result_fields + %w[derived_rounds_completed sg_rounds_observed average_field_relative_sg first_two_round_field_relative_sg classified_finishers finishing_percentile]
write_csv(File.join(OUT, 'player_event_results_normalized.csv'), normalized_result_fields, normalized_results)

cohort = results.select do |row|
  event = events_by_id.fetch(row['event_id'])
  event['competition_group'] == 'major' && Date.iso8601(event['start_date']) < LAUNCH && row['start_status'] == 'started'
end.map { |row| row['player_id'] }.uniq.sort
debut_by_player = debut_rows.transform_values { |row| Date.iso8601(row['first_liv_start_date']) }
observed_liv_starts = liv_appearances.group_by { |row| row['player_id'] }.transform_values do |rows|
  rows.map { |row| Date.iso8601(row['start_date']) }.min
end
results_by_key = normalized_results.to_h { |row| [[row['event_id'], row['player_id']], row] }
major_list = events.select { |event| event['competition_group'] == 'major' }.sort_by { |event| event['start_date'] }
panel = cohort.flat_map do |player|
  major_list.map do |major|
    result = results_by_key[[major['event_id'], player]]
    as_of = Date.iso8601(major['start_date'])
    participation = if result && result['start_status'] == 'started' then '1'
                    elsif result then 'unknown'
                    elsif major['field_verified_complete'] == 'yes' then '0'
                    else 'unknown' end
    treatment = if as_of < LAUNCH then '0'
                elsif observed_liv_starts[player] && observed_liv_starts[player] <= as_of then '1'
                elsif debut_by_player[player] && debut_by_player[player] > as_of then '0'
                else 'unknown' end
    {
      'player_id' => player, 'event_id' => major['event_id'], 'major_start_date' => major['start_date'],
      'participated' => participation, 'treatment_status' => treatment,
      'first_liv_start_date' => debut_by_player[player]&.iso8601.to_s,
      'finish_text' => result ? result['finish_text'] : '',
      'finish_position' => result ? result['finish_position'] : '',
      'cut_outcome' => result ? result['cut_outcome'] : '',
      'finishing_percentile' => result ? result['finishing_percentile'] : '',
      'average_field_relative_sg' => result ? result['average_field_relative_sg'] : ''
    }
  end
end
panel_fields = %w[player_id event_id major_start_date participated treatment_status first_liv_start_date finish_text finish_position cut_outcome finishing_percentile average_field_relative_sg]
write_csv(File.join(OUT, 'major_participation_panel.csv'), panel_fields, panel)

profiles = []
cohort.each do |player|
  major_list.each do |major|
    as_of = Date.iso8601(major['start_date'])
    historical = normalized_results.select do |result|
      result['player_id'] == player && result['start_status'] == 'started' &&
        Date.iso8601(events_by_id.fetch(result['event_id'])['end_date']) < as_of
    end
    treatment = if as_of < LAUNCH then '0'
                elsif observed_liv_starts[player] && observed_liv_starts[player] <= as_of then '1'
                elsif debut_by_player[player] && debut_by_player[player] > as_of then '0'
                else 'unknown' end
    { 'annual' => Date.new(as_of.year, 1, 1), 'trailing_365' => as_of - 365 }.each do |window, from|
      %w[pga dpwt liv major].each do |tour|
        chosen = historical.select do |result|
          event = events_by_id.fetch(result['event_id'])
          event['competition_group'] == tour && Date.iso8601(event['end_date']) >= from
        end
        chosen_rounds = chosen.flat_map { |result| rounds_by_result.fetch([result['event_id'], player], []) }
        sg = chosen_rounds.map { |round| round['field_relative_sg'] }.reject(&:empty?).map(&:to_f)
        finish = chosen.map { |result| result['finishing_percentile'] }.reject(&:empty?).map(&:to_f)
        cut_eligible = chosen.select do |result|
          events_by_id.fetch(result['event_id'])['field_verified_complete'] == 'yes' &&
            %w[made_cut missed_cut].include?(result['cut_outcome'])
        end
        profiles << {
          'player_id' => player, 'event_id' => major['event_id'], 'profile_as_of' => major['start_date'],
          'profile_window' => window, 'profile_tour' => tour, 'treatment_status' => treatment,
          'first_liv_start_date' => debut_by_player[player]&.iso8601.to_s,
          'starts' => chosen.length, 'rounds_completed' => chosen_rounds.length,
          'cut_rate' => cut_eligible.empty? ? '' : format('%.6f', cut_eligible.count { |result| result['cut_outcome'] == 'made_cut' }.to_f / cut_eligible.length),
          'average_finishing_percentile' => finish.empty? ? '' : format('%.6f', finish.sum / finish.length),
          'average_field_relative_sg' => sg.length == chosen_rounds.length && !sg.empty? ? format('%.6f', sg.sum / sg.length) : '',
          'sg_round_coverage' => chosen_rounds.empty? ? '' : format('%.6f', sg.length.to_f / chosen_rounds.length),
          'average_driving_distance_yards' => '', 'distance_round_coverage' => chosen_rounds.empty? ? '' : '0.000000'
        }
      end
    end
  end
end
profile_fields = %w[player_id event_id profile_as_of profile_window profile_tour treatment_status first_liv_start_date starts rounds_completed cut_rate average_finishing_percentile average_field_relative_sg sg_round_coverage average_driving_distance_yards distance_round_coverage]
write_csv(File.join(OUT, 'profile_snapshots.csv'), profile_fields, profiles)

# One row per golfer-major for quick exploratory joins. Prefixes make the
# observed-only nature of the profile counts explicit.
profile_lookup = profiles.to_h do |row|
  [[row['player_id'], row['event_id'], row['profile_tour'], row['profile_window']], row]
end
feature_fields = %w[observed_starts observed_rounds cut_rate average_finishing_percentile average_field_relative_sg sg_round_coverage]
feature_source = {
  'observed_starts' => 'starts', 'observed_rounds' => 'rounds_completed',
  'cut_rate' => 'cut_rate', 'average_finishing_percentile' => 'average_finishing_percentile',
  'average_field_relative_sg' => 'average_field_relative_sg',
  'sg_round_coverage' => 'sg_round_coverage'
}
flat_fields = panel_fields.dup
%w[pga dpwt liv major].each do |tour|
  %w[annual trailing_365].each do |window|
    feature_fields.each { |field| flat_fields << "#{tour}_#{window}_#{field}" }
  end
end
flat_panel = panel.map do |row|
  flat = row.dup
  %w[pga dpwt liv major].each do |tour|
    %w[annual trailing_365].each do |window|
      profile = profile_lookup.fetch([row['player_id'], row['event_id'], tour, window])
      feature_source.each do |field, source_field|
        flat["#{tour}_#{window}_#{field}"] = profile[source_field]
      end
    end
  end
  flat
end
write_csv(File.join(OUT, 'experiment_ready_major_panel.csv'), flat_fields, flat_panel)

counts_by_group_year = results.group_by { |row| event = events_by_id.fetch(row['event_id']); "#{event['competition_group']}:#{event['season']}" }.transform_values(&:length)
round_counts_by_group_year = rounds.group_by { |row| event = events_by_id.fetch(row['event_id']); "#{event['competition_group']}:#{event['season']}" }.transform_values(&:length)
events_by_group_year = source_rows.group_by { |row| "#{row['competition_group']}:#{row['end_date'][0, 4]}" }.transform_values(&:length)
sg_by_group_year = normalized_rounds.select { |row| !row['field_relative_sg'].empty? }
  .group_by { |row| event = events_by_id.fetch(row['event_id']); "#{event['competition_group']}:#{event['season']}" }
  .transform_values(&:length)
treatment_at_major = profiles.select { |row| row['profile_tour'] == 'major' && row['profile_window'] == 'annual' }
  .group_by { |row| row['treatment_status'] }.transform_values(&:length)
coverage = {
  'generated_at_utc' => '2026-10-19',
  'major_inventory_events' => major_list.length,
  'observed_events' => source_rows.length,
  'verified_complete_fields' => source_rows.count { |row| row['field_verified_complete'] == 'yes' },
  'player_event_rows' => results.length,
  'player_round_rows' => rounds.length,
  'distinct_players' => players.length,
  'major_cohort_players_observed' => cohort.length,
  'major_panel_rows' => panel.length,
  'major_panel_participation' => panel.group_by { |row| row['participated'] }.transform_values(&:length),
  'treatment_status_at_major' => treatment_at_major,
  'verified_liv_debuts' => debut_rows.length,
  'events_by_group_year' => events_by_group_year,
  'results_by_group_year' => counts_by_group_year,
  'rounds_by_group_year' => round_counts_by_group_year,
  'calculated_sg_rounds_by_group_year' => sg_by_group_year,
  'season_stat_rows' => season_stats.length,
  'season_stats_by_tour_metric' => season_stats.group_by { |row| "#{row['tour']}:#{row['season']}:#{row['metric']}" }.transform_values(&:length),
  'metric_observations' => {
    'strokes' => rounds.length,
    'field_relative_sg' => normalized_rounds.count { |row| !row['field_relative_sg'].empty? },
    'source_overall_sg' => 0, 'source_sg_components' => 0, 'driving_distance' => 0
  },
  'event_gaps' => source_rows.map do |source|
    { 'event_id' => source['event_id'], 'expected_starters' => source['expected_starters'],
      'observed_classified_finishers' => source['observed_final_results'],
      'field_verified_complete' => source['field_verified_complete'], 'note' => source['coverage_note'] }
  end,
  'unsourced_major_events' => major_list.reject { |event| sources.key?(event['event_id']) }
    .map do |event|
      reason = if %w[major-2026-pga major-2026-us-open major-2026-open].include?(event['event_id'])
                 'reviewed_secondary_table_has_missing_entries_or_score_total_conflicts'
               else
                 'player_results_not_yet_collected'
               end
      { 'event_id' => event['event_id'], 'start_date' => event['start_date'], 'gap_reason' => reason }
    end,
  'regular_tour_event_inventory_complete' => false
}
File.write(File.join(REPORTS, 'coverage_report.json'), JSON.pretty_generate(coverage) + "\n")
puts "Materialized #{source_rows.length} sourced events, #{results.length} player-event results, #{rounds.length} rounds, #{players.length} players."
puts "Verified #{debut_rows.length} LIV debut dates; #{panel.count { |row| row['participated'] == 'unknown' }} major panel cells remain unknown."
