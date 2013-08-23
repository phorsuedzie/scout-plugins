# encoding: utf-8
require File.expand_path("../opsworks_processes", __FILE__)

describe OpsworksProcesses do
  let(:plugin) do
    OpsworksProcesses.new(nil, {}, nil)
  end

  before do
    plugin.stub(:`).with('ps -C opsworks-agent -o cmd --no-headers | grep ": master" | wc -l').
        and_return 3
    plugin.stub(:`).with('ps -C opsworks-agent -o cmd --no-headers | wc -l').and_return 17
  end

  it "should report the amount of opsworks master processes" do
    plugin.run[:reports].first[:master_count].should == 3
  end

  it "should report the total amount of opsworks processes" do
    plugin.run[:reports].first[:total_count].should == 17
  end
end
