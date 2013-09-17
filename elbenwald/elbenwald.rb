require 'scout'
require 'set'

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
    {:total => 0}.tap do |statistics|
      azs = Set.new
      add_azs_statistics(statistics, azs)
      add_average_statistics(statistics, azs)
      add_minimum_statistics(statistics)
    end
  end

  def add_azs_statistics(statistics, azs)
    instance_healthes.each do |health|
      instance = health[:instance]
      az = instance.availability_zone
      azs << az
      statistics[az] ||= 0
      if health[:state] == 'InService'
        statistics[az] += 1
        statistics[:total] += 1
      else
        log_unhealthy(az, instance.id, health[:description])
      end
    end
  end

  def add_average_statistics(statistics, azs)
    number_azs = azs.size.to_f
    statistics[:average] = number_azs == 0 ? 0 : statistics[:total] / number_azs
  end

  def add_minimum_statistics(statistics)
    statistics[:minimum] = statistics.values.min || 0
  end

  def instance_healthes
    AWS::ELB.new.load_balancers[@elb_name].instances.health
  end

  def log_unhealthy(az, instance_id, description)
    File.open(File.expand_path(@error_log_path), 'a') do |f|
      f.puts("[#{Time.now}] [#{@elb_name}] [#{az}] [#{instance_id}] [#{description}]")
    end
  end
end
