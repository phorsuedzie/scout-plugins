# encoding: utf-8
require_relative "../marvel_watch"

describe MarvelWatch do
  let(:plugin) { MarvelWatch.new(nil, {}, {}) }
  let(:report) { plugin.run[:reports].first }

  it "reports the number of marvel indexes" do
    expect(Net::HTTP).to receive(:get).and_return('{
      ".marvel-2015.03.04" : { "aliases" : { } },
      ".marvel-2015.02.24" : { "aliases" : { } },
      "crm_dev_1" : { "aliases" : { } },
      ".marvel-kibana" : { "aliases" : { } },
      "crm_dev" : { "aliases" : { } }
    }')

    expect(report[:number_of_marvel_indexes]).to eq(3)
  end
end
