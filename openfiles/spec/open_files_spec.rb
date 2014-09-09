# encoding: utf-8
require_relative "../open_files"

describe OpenFiles do
  let(:plugin) do
    OpenFiles.new(nil, {}, :user => 'some_test_user')
  end

  it "should report the amount of open files for the specified user" do
    expect(plugin).to receive(:`).with('sudo lsof -u some_test_user | wc -l').and_return "13"
    expect(plugin.run[:reports].first[:open_files]).to eq(13)
  end
end
