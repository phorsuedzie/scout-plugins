# encoding: utf-8
require_relative "../say_cheese"

describe SayCheese do
  let(:plugin) do
    SayCheese.new(nil, {}, {state_file: state_file})
  end
  let(:plugin_output) do
    # parsed timestamp should be one minute ago, regardless of current time.
    expect(Time).to receive(:parse).with('2014-11-06 09:00 UTC').and_return(Time.now.utc - 60)
    expect(Time).to receive(:now).and_call_original

    plugin.run
  end
  let(:report) do
    plugin_output[:reports].first
  end
  let(:alert) do
    plugin_output[:alerts].first
  end

  context 'with a successful state_file' do
    let!(:state_file) { File.expand_path('../successful.json', __FILE__) }

    it "reports the correct total/successful/failed and time ago" do
      expect(report[:shards_total]).to eq(10)
      expect(report[:shards_successful]).to eq(10)
      expect(report[:shards_failed]).to eq(0)
      expect(report[:snapshot_started_minutes_ago]).to eq(1)
    end

    it "does not alert" do
      expect(alert).to be_nil
    end
  end

  context 'with a failed state_file' do
    let!(:state_file) { File.expand_path('../failed.json', __FILE__) }

    it "reports the correct total/successful/failed and time ago" do
      expect(report[:shards_total]).to eq(10)
      expect(report[:shards_successful]).to eq(8)
      expect(report[:shards_failed]).to eq(2)
      expect(report[:snapshot_started_minutes_ago]).to eq(1)
    end

    it "alerts about the failed shards" do
      expect(alert[:body]).to include('2 of 10 shards')
      expect(alert[:subject]).to include('2 shards failed')
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

    it "does not alert" do
      expect(alert).to be_nil
    end
  end
end
