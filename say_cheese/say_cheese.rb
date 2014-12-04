require 'scout'

class SayCheese < Scout::Plugin
  OPTIONS = <<-EOS
  state_file:
    default: /var/log/elasticsearch_snapshots/state.json
    name: State File
    notes: Path to the snapshot statistics file (see create_snapshot.rb)
  EOS

  def build_report
    statistics = parse_json_file(option(:state_file))

    minutes = minutes_ago(statistics['started_at'])
    shards_stats = statistics['shards_stats'] || {}
    total = shards_stats['total'] || 0
    done = shards_stats['done'] || 0
    failed = shards_stats['failed'] || 0
    duration = duration(statistics['started_at'], statistics['ended_at'])

    report({
      shards_total: total,
      shards_successful: done,
      shards_failed: failed,
      snapshot_started_minutes_ago: minutes,
      snapshot_duration_in_seconds: duration,
    })
  end

  def parse_json_file(state_file)
    JSON.parse(IO.read(state_file))
  end

  def minutes_ago(time)
    ((Time.now.utc - Time.parse(time)) / 60).to_i
  rescue TypeError
    nil
  end

  def duration(start_time, end_time)
    (Time.parse(end_time) - Time.parse(start_time)).round
  rescue TypeError
    nil
  end
end
