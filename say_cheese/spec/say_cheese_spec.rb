# encoding: utf-8
require 'timecop'
require_relative "../say_cheese"

describe SayCheese do
  let(:plugin) { SayCheese.new(nil, {}, {state_file: state_file}) }
  let(:report) { plugin.run[:reports].first }
  let(:now) { Time.parse('2014-11-06 09:01 UTC') }
  before { Timecop.freeze(now) }
  after { Timecop.return }

  context 'with a master node state' do
    let!(:state_file) { File.expand_path('../master_node.json', __FILE__) }

    it "reports the correct total/successful/failed and time ago" do
      expect(report[:shards_total]).to eq(10)
      expect(report[:shards_successful]).to eq(8)
      expect(report[:shards_failed]).to eq(2)
      expect(report[:snapshot_started_minutes_ago]).to eq(1)
    end

    it "reports the duration in seconds" do
      expect(report[:snapshot_duration_in_seconds]).to eq(90)
    end
  end

  context 'with a non master node state' do
    let!(:state_file) { File.expand_path('../not_master_node.json', __FILE__) }

    it "reports the correct time ago and 0 as total/successful/failed" do
      expect(report[:shards_total]).to eq(0)
      expect(report[:shards_successful]).to eq(0)
      expect(report[:shards_failed]).to eq(0)
      expect(report[:snapshot_started_minutes_ago]).to eq(1)
    end

    it "reports the duration in seconds" do
      expect(report[:snapshot_duration_in_seconds]).to eq(0)
    end
  end

  context 'with an empty json file' do
    let!(:state_file) { File.expand_path('../empty_hash.json', __FILE__) }

    it "reports nil as time ago and 0 as total/successful/failed" do
      expect(report[:shards_total]).to eq(0)
      expect(report[:shards_successful]).to eq(0)
      expect(report[:shards_failed]).to eq(0)
      expect(report[:snapshot_started_minutes_ago]).to be_nil
    end

    it "reports nil as the duration in seconds" do
      expect(report[:snapshot_duration_in_seconds]).to be_nil
    end
  end
end
