# encoding: utf-8
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
    return error("Please provide a path to the log file.") if log_path.empty?
    return error("Could not find the log file.") unless File.exists?(log_path)

    if remaining_bytes > (10 * 1024 * 1024)
      skip
    else
      analyze
    end

    remember :inode => current_inode
  end

  private

  def patterns
    # Scout replaces any multibyte UTF-8 character by '?'.
    # Therefore the split character ('↓') is hex encoded.
    @patterns ||= [/^\s*$/] + option("ignore").to_s.strip.split("\xe2\x86\x93").map {|s| /#{s}/}
  end

  def log_path
    @log_path ||= option(:log_path).to_s.strip
  end

  def last_bytes
    @last_bytes ||= (last_inode == current_inode) ? (memory(:size) || 0) : 0
  end

  def last_inode
    @last_inode ||= memory(:inode)
  end

  def stat
    @stat ||= File.stat(log_path)
  end

  def current_inode
    stat.ino
  end

  def current_bytes
    stat.size
  end

  def remaining_bytes
    current_bytes - last_bytes
  end

  def analyze
    unexpected = []
    File.open(log_path, "r:UTF-8") do |f|
      f.pos = last_bytes
      begin
        while true
          size = f.pos
          line = f.readline
          if line[-1] != "\n"[0]
            remember :size => size
            break
          end
          begin
            unexpected << line unless patterns.detect {|p| line =~ p}
          rescue ArgumentError
            line.force_encoding(Encoding::ISO_8859_15)
            line.encode(Encoding::UTF_8)
            unexpected << line
          end
        end
      rescue EOFError
        remember :size => f.pos
      end
    end
    alert("Unrecognized lines in '#{log_path}'", unexpected.join) unless unexpected.empty?
    report(:lines_reported => unexpected.size)
  end

  def skip
    remember :size => current_bytes
    alert("Too much log data in '#{log_path}'",
        "The file '#{log_path}' has #{(remaining_bytes.to_f / 1024 / 1024).round 2} MB of " +
        "unanalyzed log data. This will be skipped.")
    report(:lines_reported => 0)
  end
end
