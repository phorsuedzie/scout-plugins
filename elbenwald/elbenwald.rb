require 'scout'

class Elbenwald < Scout::Plugin
  OPTIONS = <<-EOS
  elb_name:
    name: ELB name
    notes: Name of the ELB
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
    @elb_name = option(:elb_name).to_s.strip
    @aws_credentials_path = option(:aws_credentials_path).to_s.strip
    @error_log_path = option(:error_log_path).to_s.strip

    return error('Please provide name of the ELB') if @elb_name.empty?
    return error('Please provide a path to AWS configuration') if @aws_credentials_path.empty?
    return error('Please provide a path error log') if @error_log_path.empty?

    configure

    report(build_statistics)
  end

  private

  def configure
    AWS.config(YAML.load_file(File.expand_path(@aws_credentials_path)))
  end

  def build_statistics
    healthy_count = Hash.new(0)

    AWS::ELB.new.load_balancers[@elb_name].instances.health.each do |health|
      instance, state = health[:instance], health[:state]
      az = instance.availability_zone
      healthy = state == 'InService' or log_unhealthy(az, instance.id, health[:description])
      healthy_count[az] += healthy ? 1 : 0
    end

    total_healthy_count = healthy_count.values.reduce(:+)
    healthy_count.merge({
      :total => total_healthy_count,
      :minimum => healthy_count.values.min,
      :average => healthy_count.empty? ? 0 : total_healthy_count / healthy_count.size.to_f,
    })
  end

  def log_unhealthy(az, instance_id, description)
    File.open(File.expand_path(@error_log_path), 'a') do |f|
      f.puts("[#{Time.now}] [#{@elb_name}] [#{az}] [#{instance_id}] [#{description}]")
    end
  end
end
