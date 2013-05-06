require 'scout'

class Elbenwald < Scout::Plugin
  needs 'aws-sdk'
  needs 'yaml'

  OPTIONS = <<-EOS
    aws_credentials_path:
      name: AWS credentials path
      note: Full path to a YAML file with AWS credentials
    error_log_path
      name: Error log path
      note: Full path to error log file
  EOS

  def build_report
    aws_credentials_path = option(:aws_credentials_path).to_s.strip
    error_log_path = option(:error_log_path).to_s.strip

    return error('Please provide a path to AWS configuration') if aws_credentials_path.empty?
    return error('Please provide a path error log') if error_log_path.empty?

    statistics = {}

    AWS::ELB.new(YAML.load_file(aws_credentials_path)).load_balancers.each do |load_balancer|
      load_balancer.instances.health.each do |health|
        instance = health[:instance]
        if health[:state] == 'InService'
          metric_name = "#{load_balancer.name}-#{instance.availability_zone}"
          statistics[metric_name] ||= 0
          statistics[metric_name] += 1
        else
          File.open(error_log_path, 'a') do |f|
            f.puts("[#{Time.now}] [#{instance.id}] [#{health[:description]}]")
          end
        end
      end
    end

    report(statistics)
  end
end
