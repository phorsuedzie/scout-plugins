# encoding: utf-8
require_relative "../opsworks_processes"

describe OpsworksProcesses do
  def perform_run(master_count, total_count, with_memory = false, memory = nil)
    @memory = memory if memory
    plugin = OpsworksProcesses.new(nil, with_memory ? (@memory || {}) : {}, nil)
    plugin.should_receive(:`).
        with('ps -C opsworks-agent -o cmd --no-headers | grep ": master" | wc -l').
        and_return master_count
    plugin.should_receive(:`).
        with('ps -C opsworks-agent -o cmd --no-headers | wc -l').and_return total_count
    if block_given?
      yield plugin
    end
    plugin.run.tap do |result|
      @memory = result[:memory]
    end
  end

  it "should report the amount of opsworks master processes" do
    perform_run(3, 17)[:reports].first[:master_count].should == 3
  end

  it "should report the total amount of opsworks processes" do
    perform_run(3, 17)[:reports].first[:total_count].should == 17
  end

  it "should remember the last ten values for master process count" do
    perform_run(3, 0, true)[:memory].should == {master_count: [3] }
    perform_run(4, 0, true)[:memory].should == {master_count: [3, 4] }
    perform_run(5, 0, true)[:memory].should == {master_count: [3, 4, 5] }
    perform_run(6, 0, true)[:memory].should == {master_count: [3, 4, 5, 6] }
    perform_run(3, 0, true)[:memory].should == {master_count: [3, 4, 5, 6, 3] }
    perform_run(1, 0, true)[:memory].should == {master_count: [3, 4, 5, 6, 3, 1] }
    perform_run(5, 0, true)[:memory].should == {master_count: [3, 4, 5, 6, 3, 1, 5] }
    perform_run(6, 0, true)[:memory].should == {master_count: [3, 4, 5, 6, 3, 1, 5, 6] }
    perform_run(3, 0, true)[:memory].should == {master_count: [3, 4, 5, 6, 3, 1, 5, 6, 3] }
    perform_run(4, 0, true)[:memory].should == {master_count: [3, 4, 5, 6, 3, 1, 5, 6, 3, 4] }
    perform_run(5, 0, true)[:memory].should == {master_count: [4, 5, 6, 3, 1, 5, 6, 3, 4, 5] }
    perform_run(6, 0, true)[:memory].should == {master_count: [5, 6, 3, 1, 5, 6, 3, 4, 5, 6] }
  end

  it "should kill all opsworks processes if there was more than one master for ten times" do
    perform_run(3, 0, true, {master_count: [31, 32, 33, 34, 35, 36, 37, 38, 39]}) do |plugin|
      plugin.should_receive(:`).with('sudo -n /usr/bin/killall -9 opsworks-agent')
    end
  end

  it "should not kill all opsworks processes if there are not at least ten master count values" do
    perform_run(3, 0, true, {master_count: [31, 32, 33, 34, 35, 36, 37, 38]}) do |plugin|
      plugin.should_not_receive(:`).with('sudo -n /usr/bin/killall -9 opsworks-agent')
    end
  end

  it "should not kill all opsworks processes if not all master counts are greater than one" do
    perform_run(3, 0, true, {master_count: [31, 32, 33, 34, 1, 36, 37, 38, 39]}) do |plugin|
      plugin.should_not_receive(:`).with('sudo -n /usr/bin/killall -9 opsworks-agent')
    end
  end
end
