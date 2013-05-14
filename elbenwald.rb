require 'scout'

class Elbenwald < Scout::Plugin
  OPTIONS = <<-EOS
  aws_credentials_path:
    name: AWS credentials path
    notes: Full path to a YAML file with AWS credentials
    default: ~/elbenwald.yml
  error_log_path:
    name: Error log path
    notes: Full path to error log file
    default: ~/elbenwald.error.log
  EOS

  needs 'aws-sdk'
  needs 'yaml'

  def build_report
    aws_credentials_path = option(:aws_credentials_path).to_s.strip
    error_log_path = option(:error_log_path).to_s.strip

    return error('Please provide a path to AWS configuration') if aws_credentials_path.empty?
    return error('Please provide a path error log') if error_log_path.empty?

    statistics = {total: 0}

    AWS.config(YAML.load_file(aws_credentials_path))

    AWS::ELB.new.load_balancers.each do |load_balancer|
      load_balancer.instances.health.each do |health|
        instance = health[:instance]
        load_balancer_name = load_balancer.name
        availability_zone = instance.availability_zone
        if health[:state] == 'InService'
          metric_name = "#{load_balancer_name}-#{availability_zone}"
          statistics[metric_name] ||= 0
          statistics[metric_name] += 1
          statistics[:total] += 1
        else
          File.open(error_log_path, 'a') do |f|
            f.puts("[#{Time.now}] [#{load_balancer_name}] [#{availability_zone}]" \
                " [#{instance.id}] [#{health[:description]}]")
          end
        end
      end
    end

    report(statistics)
  end
end
