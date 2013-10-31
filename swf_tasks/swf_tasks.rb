require 'scout'

class SwfTasks < Scout::Plugin
  needs 'aws-sdk'
  needs 'yaml'
  needs 'json'

  OPTIONS = <<-EOS
  workflow_list_mapping:
    name: Workflow List to Application Mapping
    notes: JSON formatted mapping
    default: '{"console": "console", "webcrm-tasklist": "crm", "cms": "cms"}'
  EOS

  def workflow_list_mapping
    @workflow_list_mapping ||= JSON(option(:workflow_list_mapping) || "{}")
  end

  def app_name_from_execution(execution)
    task_list = execution.task_list
    workflow_list_mapping[task_list] ||
        case task_list
        when /cms/
          "cms"
        when /crm/
          "crm"
        when /console/
          "console"
        else
          "unknown"
        end
  end

  def metric_key(name, app_provider)
    app =
        case app_provider
        when String
          app_provider
        else
          app_name_from_execution(app_provider)
        end
    "#{app}_#{name}_tasks"
  end

  def swf_domain
    config = YAML.load_file("/home/scout/swf_tasks.yml")
    domain = AWS::SimpleWorkflow.new({
      :access_key_id => config["simple_workflow_access_key_id"],
      :secret_access_key => config["simple_workflow_secret_access_key"],
      :simple_workflow_endpoint => config["simple_workflow_endpoint"],
      :use_ssl => true,
    }).domains[config["simple_workflow_domain"]]
  end

  def open_executions
    swf_domain.workflow_executions.with_status(:open)
  end

  def current_host
    @hostname ||= `hostname`.strip
  end

  def zombie_on_current_host?(event)
    identity = event.attributes[:identity]
    raise "Missing identity in event: attributes = #{event.attributes}" unless identity
    hostname, pid = identity.split(":")
    raise "Unexpected identity #{identity} - cannot split by :" unless pid
    raise "Unexpected pid #{pid} from identity" unless pid.to_i.to_s == pid
    return false unless hostname == current_host
    return false if File.exists?("/proc/#{pid}")
    # the inspected event is still the last event of the execution
    return false unless event.id == event.workflow_execution.history_events.reverse_order.first.id
    w = event.workflow_execution
    File.open(File.expand_path("~/swf_tasks.log"), "a") do |f|
      f.puts "[#{Time.now}] Zombie: id: [#{w.workflow_id}, #{w.run_id}] details: #{w.history_events.first.attributes.to_h}"
    end
    true
  rescue => e
    error e.message
  end

  def statistics
    @statistics ||= begin
      statistics = Hash.new(0)
      %w[waiting zombie].each do |type|
        workflow_list_mapping.values.each do |app|
          statistics[metric_key(type, app)] = 0
        end
      end
      statistics
    end
  end

  def build_report
    open_executions.each do |ex|
      last_event = ex.history_events.reverse_order.first
      case last_event.event_type
      when "ActivityTaskScheduled"
        statistics[metric_key("waiting", ex)] += 1
      when "ActivityTaskStarted", "DecisionTaskStarted"
        statistics[metric_key("zombie", ex)] += 1 if zombie_on_current_host?(last_event)
      end
    end
    report(statistics)
  end
end
