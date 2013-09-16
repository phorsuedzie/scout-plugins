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

  def app_name(real_task_list)
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

  def build_report
    config = YAML.load_file("/home/scout/swf_tasks.yml")
    domain = AWS::SimpleWorkflow.new({
      :access_key_id => config["simple_workflow_access_key_id"],
      :secret_access_key => config["simple_workflow_secret_access_key"],
      :simple_workflow_endpoint => config["simple_workflow_endpoint"],
      :use_ssl => true,
    }).domains[config["simple_workflow_domain"]]

    statistics = Hash.new(0)
    workflow_list_mapping.values.each {|app| statistics["#{app}_waiting_tasks"] += 0}
    domain.workflow_executions.with_status(:open).each do |ex|
      app = app_name(ex.task_list)
      last_event = ex.history_events.reverse_order.first
      case last_event.event_type
      when "ActivityTaskScheduled"
        metric = "#{app}_waiting_tasks"
        statistics[metric] += 1
      end
    end
    report(statistics)
  end
end
