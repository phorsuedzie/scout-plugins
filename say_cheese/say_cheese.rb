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

    name = statistics['snapshot_name']
    at = statistics['started_at']
    minutes = minutes_ago(at)

    total = statistics['shards_stats']['total'] || 0
    done = statistics['shards_stats']['done'] || 0
    failed = statistics['shards_stats']['failed'] || 0

    report({
      shards_total: total,
      shards_successful: done,
      shards_failed: failed,
      snapshot_started_minutes_ago: minutes,
    })
    if failed > 0
      alert("#{failed} shards failed during the last '#{name}' snapshot",
          "The last snapshot '#{name}' started #{minutes} minutes ago (at #{at}) " \
          "has failed to backup #{failed} of #{total} shards.")
    end
  end

  def parse_json_file(state_file)
    JSON.parse(IO.read(state_file))
  end

  def minutes_ago(time)
    ((Time.now.utc - Time.parse(time)) / 60).to_i
  end
end
