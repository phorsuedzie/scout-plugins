require 'scout'

class SwfTasks < Scout::Plugin
  needs 'aws-sdk'
  needs 'yaml'
  needs 'json'

  OPTIONS = <<-EOS
  workflow_list_mapping:
    name: Workflow List to Application Mapping
    notes: JSON formatted mapping
    default: '{"master": "unit", "webcrm-tasklist": "crm", "cms": "cms"}'
  workflow_unit_mapping:
    name: Workflow Unit to Application Mapping
    notes: JSON formatted mapping
    default: '{"scrivitocom": "dashboard", "scrival-cms": "backend"}'
  EOS

  def workflow_list_mapping
    @workflow_list_mapping ||= JSON(option(:workflow_list_mapping) || "{}")
  end

  def workflow_unit_mapping
    @workflow_unit_mapping ||= JSON(option(:workflow_unit_mapping) || "{}")
  end

  def app_name_from_unit(execution)
    first_event = execution.history_events.first
    input_as_json = first_event.attributes[:input] or return nil
    input = JSON(input_as_json)
    unit = input["unit"]
    resolved_unit = workflow_unit_mapping[unit] and return resolved_unit
    case unit
    when /scrivitocom/
      "dashboard"
    when /crm/
      "crm"
    when /console/
      "console"
    when /cms/
      unit.include?("scriv") ? "backend" : "cms"
    else
      nil
    end
  end

  def app_name_from_event(event)
    execution = event.workflow_execution
    task_list = execution.task_list
    resolved_task_list = workflow_list_mapping[task_list]
    case resolved_task_list
    when "unit"
      app_name_from_unit(execution)
    when String
      resolved_task_list
    else
      case task_list
      when /cms/
        "cms"
      when /crm/
        "crm"
      when /console/
        "console"
      end
    end || "unknown"
  end

  def metric_key(name, app_or_event)
    app =
        case app_or_event
        when String
          app_or_event
        else
          app_name_from_event(app_or_event)
        end
    "#{app}_#{name}_tasks"
  end

  def swf_config
    @swf_config ||= YAML.load_file("/home/scout/swf_tasks.yml")
  end

  def swf_domain
    domain = AWS::SimpleWorkflow.new({
      :access_key_id => swf_config["simple_workflow_access_key_id"],
      :secret_access_key => swf_config["simple_workflow_secret_access_key"],
      :simple_workflow_endpoint => swf_config["simple_workflow_endpoint"],
      :use_ssl => true,
    }).domains[swf_config["simple_workflow_domain"]]
  end

  def open_executions
    swf_domain.workflow_executions.with_status(:open)
  end

  def my_host
    @hostname ||= `hostname`.strip
  end

  def my_stack_id
    swf_config["stack_id"]
  end

  def zombie?(event)
    identity = event.attributes[:identity]
    raise "Missing identity in event: attributes = #{event.attributes}" unless identity
    hostname, pid, stack_id = identity.split(":")
    raise "Unexpected identity #{identity} - cannot split by :" unless pid
    raise "Unexpected pid #{pid} from identity #{identity}" unless pid.to_i.to_s == pid
    return false unless hostname == my_host
    # requires stack_id to be both configured via config and provided by event
    return false if my_stack_id && stack_id && my_stack_id != stack_id
    return false if File.exists?("/proc/#{pid}")
    # the inspected event is still the last event of the execution
    return false unless event.id == event.workflow_execution.history_events.reverse_order.first.id
    w = event.workflow_execution
    File.open(File.expand_path("~/swf_tasks.log"), "a") do |f|
      f.puts %|[#{Time.now}] Zombie (execution: Rails.application.workflow.ntswf.domain.workflow_executions.at["#{w.workflow_id}", "#{w.run_id}"] details: #{w.history_events.first.attributes.to_h})|
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
          if app == "unit"
            workflow_unit_mapping.values.each do |app|
              statistics[metric_key(type, app)] = 0
            end
          else
            statistics[metric_key(type, app)] = 0
          end
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
        statistics[metric_key("waiting", last_event)] += 1
      when "ActivityTaskStarted", "DecisionTaskStarted"
        if zombie?(last_event)
          statistics[metric_key("zombie", last_event)] += 1
        end
      end
    end
    report(statistics)
  end
end
