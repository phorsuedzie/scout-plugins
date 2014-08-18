plugin_source_file = __FILE__.sub("_spec", "")
require_relative plugin_source_file.sub(".rb", "")
plugin_source_code = File.read(plugin_source_file)

plugin_source_code.scan(/needs ["'](.*?)["']/).flatten.each do |lib|
  require lib
end

describe SwfTasks do
  def build_execution(task_list, id, event_types)
    execution = double("execution #{task_list} #{id}", task_list: task_list)
    events = event_types.each_with_index.map do |type, index|
      id = "#{task_list} #{id} ##{index + 1}"
      double("Event #{id}", event_type: type, workflow_execution: execution, id: id)
    end
    allow(execution).to receive(:history_events).and_return(events)
    execution
  end

  let(:plugin_config_from_cloud_or_app_config) {
    Hash.new {|h, k| raise "Unexpected /home/scout/swf_tasks.yml config access: #{k}"}
  }

  let(:aws_swf) {
    double(AWS::SimpleWorkflow, domains: Hash.new {|h, k| raise "Unexpected domain #{k}"}).tap {|swf|
      swf.domains["swf_dom"] = aws_domain
    }
  }

  let(:aws_domain) {double(AWS::SimpleWorkflow::Domain, workflow_executions: workflow_executions)}
  let(:workflow_executions) {double(AWS::SimpleWorkflow::WorkflowExecutionCollection)}

  let(:executions) {[
    build_execution("webcrm-tasklist", "1", %w[WorkflowExecutionStarted ActivityTaskScheduled]),
    build_execution("webcrm-tasklist", "2", %w[WorkflowExecutionStarted]),
    build_execution("webcrm-tasklist", "3", %w[WorkflowExecutionStarted ActivityTaskScheduled]),
    build_execution("changed-crm", "4", %w[WorkflowExecutionStarted ActivityTaskScheduled]),
    build_execution("cms", "5", %w[WorkflowExecutionStarted ActivityTaskScheduled]),
    # nothing for console
  ]}
  let(:last_run) {nil}
  let(:memory) {Hash.new}
  let(:options) {
    options_as_string = Scout::Plugin.extract_options_yaml_from_code(plugin_source_code)
    parsed_options = Scout::PluginOptions.from_yaml(options_as_string)
    parsed_options.select {|opt| opt.has_default?}.inject({}) do |memo, opt|
      expect(opt.default).to be_a(String)
      memo[opt.name.to_sym] = opt.default; memo
    end
  }
  let(:plugin) {SwfTasks.new(last_run, memory, options)}
  let(:reports) {plugin.run[:reports]}
  let(:report) {reports.first}

  before do
    plugin_config_from_cloud_or_app_config["simple_workflow_access_key_id"] = "aki"
    plugin_config_from_cloud_or_app_config["simple_workflow_secret_access_key"] = "sak"
    plugin_config_from_cloud_or_app_config["simple_workflow_endpoint"] = "swf_ep"
    plugin_config_from_cloud_or_app_config["simple_workflow_domain"] = "swf_dom"

    expect(YAML).to receive(:load_file).with("/home/scout/swf_tasks.yml").
        and_return(plugin_config_from_cloud_or_app_config)
    expect(AWS::SimpleWorkflow).to receive(:new).with({
      access_key_id: "aki",
      secret_access_key: "sak",
      simple_workflow_endpoint: "swf_ep",
      use_ssl: true,
    }).and_return(aws_swf)


    aws_swf.domains["swf_dom"] = aws_domain

    executions.each do |execution|
      class << execution.history_events
        alias reverse_order reverse
      end
    end

    expect(workflow_executions).to receive(:with_status).with(:open).and_return(executions.each)
  end

  it "reports one report" do
    expect(reports.size).to eq(1)
  end

  it "reports open and zombie tasks for every configured application (regardless of occurence)" do
    expect(report.keys).to match_array(
        %w[console_waiting_tasks crm_waiting_tasks cms_waiting_tasks] +
        %w[console_zombie_tasks crm_zombie_tasks cms_zombie_tasks])
    expect(report["console_waiting_tasks"]).to eq(0)
    expect(report["console_zombie_tasks"]).to eq(0)
  end

  it "counts the number of open tasks per application" do
    expect(report["console_waiting_tasks"]).to eq(0)
    expect(report["cms_waiting_tasks"]).to eq(1)
  end

  it "auto-guesses the application from the task list name" do
    expect(report).to_not have_key("changed-crm_waiting_tasks")
    expect(report).to_not have_key("unknown_waiting_tasks")
    expect(report["crm_waiting_tasks"]).to eq(2 + 1)
  end

  context "when a zombie task is present" do
    let(:executions) {[
      build_execution("webcrm-tasklist", "1", %w[WorkflowExecutionStarted ActivityTaskStarted]),
      build_execution("webcrm-tasklist", "2", %w[WorkflowExecutionStarted DecisionTaskStarted]),
      build_execution("webcrm-tasklist", "3", %w[WorkflowExecutionStarted ActivityTaskStarted]),
    ]}

    before do
      %w[local:1 local:2 foreign:1].each_with_index do |identity, i|
        attributes = double("attributes #{i}")
        expect(attributes).to receive(:[]).with(:identity).and_return(identity)
        allow(executions[i].history_events.last).to receive(:attributes).and_return(attributes)
      end

      allow(plugin).to receive(:`).with("hostname").and_return("local\n")

      expect(File).to receive(:exists?).with("/proc/1").and_return(true)
      expect(File).to receive(:exists?).with("/proc/2").and_return(false)

      start_attributes = double("start_attributes", to_h: {"written" => "to log for zombie"})
      expect(executions[1].history_events.first).to receive(:attributes).and_return(start_attributes)
      expect(executions[1]).to receive(:workflow_id).and_return("ID Part 1")
      expect(executions[1]).to receive(:run_id).and_return("ID Part 2")

      io = double("io")
      expect(File).to receive(:open).and_yield(io)
      expect(io).to receive(:puts) {|message|
        expect(message).to include("ID Part 1", "ID Part 2", "written", "to log for zombie")
      }
    end

    it "detects started local tasks without process" do
      expect(report["crm_zombie_tasks"]).to eq(1)
    end
  end

end
