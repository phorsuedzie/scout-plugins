require 'scout'

class LogCheck < Scout::Plugin
  OPTIONS = <<-EOS
  log_path:
    name: Log path
    notes: Full path to the the log file
  ignore:
    name: Ignore patterns
    notes: Returns all lines not matching one of these patterns.
  EOS

  def build_report
    log_path = option(:log_path).to_s.strip
    return error("Please provide a path to the log file.") if log_path.empty?
    return error("Could not find the log file.") unless File.exists?(log_path)

    patterns = option("ignore").to_s.strip.split("↓").map {|s| /#{s}/}

    last_inode = memory(:inode)
    stat = File.stat(log_path)
    current_inode = stat.ino
    current_bytes = stat.size
    last_bytes = (last_inode == current_inode) ? (memory(:size) || 0) : 0
    remember :inode => current_inode
    unexpected = []
    File.open(log_path, "r") do |f|
      f.pos = last_bytes
      begin
        while true
          size = f.pos
          line = f.readline
          if line[-1] != "\n"[0]
            remember :size => size
            break
          end
          unexpected << line unless patterns.detect {|p| line =~ p}
        end
      rescue EOFError
        remember :size => f.pos
      end
    end
    alert("Unrecognized lines in '#{log_path}'", unexpected.join) unless unexpected.empty?
    report(:lines_reported => unexpected.size)
  end
end
