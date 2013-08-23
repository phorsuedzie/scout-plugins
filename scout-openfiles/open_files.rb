# encoding: utf-8
require 'scout'

class OpenFiles < Scout::Plugin
  OPTIONS = <<-EOS
  user:
    name: User
    notes: Login for which the open files should be counted
  EOS

  def build_report
    user = option(:user).to_s.strip
    return error("Please provide a user.") if user.empty?

    report(:open_files => `sudo lsof -u #{user} | wc -l`.to_i)
  end
end
