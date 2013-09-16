# encoding: utf-8
require File.expand_path("../open_files", __FILE__)

describe OpenFiles do
  let(:plugin) do
    OpenFiles.new(nil, {}, :user => 'some_test_user')
  end

  it "should report the amount of open files for the specified user" do
    plugin.should_receive(:`).with('sudo lsof -u some_test_user | wc -l').and_return "13"
    plugin.run[:reports].first[:open_files].should == 13
  end
end
