# encoding: utf-8
require 'scout'

class OpsworksProcesses < Scout::Plugin
  def build_report
    report(
      :master_count => `ps -C opsworks-agent -o cmd --no-headers | grep ": master" | wc -l`.to_i,
      :total_count => `ps -C opsworks-agent -o cmd --no-headers | wc -l`.to_i
    )
  end
end
