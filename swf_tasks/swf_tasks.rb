require 'scout'

class SwfTasks < Scout::Plugin
  needs 'aws-sdk'
  needs 'yaml'

  OPTIONS = <<-EOS
  workflow_list_mapping:
    name: Workflow List to Application Mapping
    notes: JSON formatted mapping
    default: {"console": "console", "webcrm-tasklist": "crm", "cms": "cms"}
  EOS

  def workflow_list_mapping
    @workflow_list_mapping ||= option(:workflow_list_mapping) || {}
  end

  def app_name_for_task_list(real_task_list)
    workflow_list_mapping[real_task_list] ||
        case real_task_list
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

  def metric_for_app(app, category = "waiting_tasks")
    "#{app}_#{category}"
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

  def statistics
    @statistics ||= begin
      statistics = Hash.new(0)
      workflow_list_mapping.values.each {|app| statistics[metric_for_app(app)] = 0}
      statistics
    end
  end

  def build_report
    open_executions.each do |ex|
      last_event = ex.history_events.reverse_order.first
      app = app_name_for_task_list(ex.task_list)
      case last_event.event_type
      when "ActivityTaskScheduled"
        statistics[metric_for_app(app)] += 1
      when "ActivityTaskStarted"
        metric = metric_for_app(app, "max_task_duration")
        event_start = last_event.created_at
        duration = Time.now - event_start
        if duration > statistics[metric]
          statistics[metric] = duration.to_i
          first_event = ex.history_events.first
          statistics["#{metric}_name"] = "#{ex.workflow_id}: #{first_event.attributes[:input]}"
        end
      end
    end
    report(statistics)
  end
end
