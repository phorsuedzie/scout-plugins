# encoding: utf-8
require 'scout'

class OpsworksProcesses < Scout::Plugin
  def build_report
    master_count = `ps -C opsworks-agent -o cmd --no-headers | grep ": master" | wc -l`.to_i
    master_count_history = ((memory(:master_count) || []) + [master_count]).last 10
    remember(:master_count => master_count_history)
    report(
      :master_count => master_count,
      :total_count => `ps -C opsworks-agent -o cmd --no-headers | wc -l`.to_i
    )
    if master_count_history.size > 9 && master_count_history.all? {|count| count > 1 }
      `sudo -n /usr/bin/killall -9 opsworks-agent`
    end
  end
end
