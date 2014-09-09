require 'fileutils'
require 'timecop'

require File.expand_path('../../elbenwald', __FILE__)

describe Elbenwald do

  before do
    File.open('/tmp/elbenwald.yml', 'w') do |f|
      f.write({
        :access_key_id     => 'xxx',
        :region            => 'zzz',
        :secret_access_key => 'yyy',
      }.to_yaml)
    end

    FileUtils.rm_rf('/tmp/elbenwald.log')
  end

  context 'with ELB name missing' do
    it 'raises an error' do
      plugin = Elbenwald.new(nil, {}, {})
      expect(plugin.run[:errors].first[:subject]).to eq('Please provide name of the ELB')
      expect(plugin.run[:errors].first[:body]).to eq('Please provide name of the ELB')
    end
  end

  context 'with AWS credentials path missing' do
    it 'raises an error' do
      plugin = Elbenwald.new(nil, {}, {:elb_name => 'my_elb'})
      expect(plugin.run[:errors].first[:subject]).to eq('Please provide a path to AWS configuration')
      expect(plugin.run[:errors].first[:body]).to eq('Please provide a path to AWS configuration')
    end
  end

  context 'with error log path missing' do
    it 'raises an error' do
      plugin = Elbenwald.new(nil, {}, {:elb_name => 'my_elb',
          :aws_credentials_path => '/tmp/elbenwald.yml'})
      expect(plugin.run[:errors].first[:subject]).to eq('Please provide a path error log')
      expect(plugin.run[:errors].first[:body]).to eq('Please provide a path error log')
    end
  end

  context 'with correct options' do
    def mock_health(id, az)
      health = Hash.new {|h, k| raise "Unexpected key access: #{k}"}
      health[:instance] = double(:id => id, :availability_zone => az)
      health
    end

    def healthy(id, az)
      mock_health(id, az).merge!(:state => 'InService')
    end

    def unhealthy(id, az)
      mock_health(id, az).merge!(:state => 'OutOfService', :description => "Unhealthy #{id}")
    end

    def transient(id, az)
      mock_health(id, az).merge!(state: "I don't know", description: "A transient error occurred. Please try again later.")
    end

    let :plugin do
      Elbenwald.new(nil, {}, :elb_name => 'my_elb', :aws_credentials_path => '/tmp/elbenwald.yml',
          :error_log_path => '/tmp/elbenwald.log')
    end

    let(:any_healthy_states) {[
      healthy('i1', 'eu-1'),
      unhealthy('i2', 'eu-1'),
      unhealthy('i3', 'eu-1'),

      healthy('i4', 'eu-2'),
      healthy('i5', 'eu-2'),
      unhealthy('i6', 'eu-2'),

      healthy('i7', 'eu-3'),
      healthy('i8', 'eu-3'),
      healthy('i9', 'eu-3'),
    ]}

    let(:healthy_and_transient_states) {[
      healthy('i1', 'eu-1'), healthy('i2', 'eu-1'), transient('i3', 'eu-1'),
      transient('i4', 'eu-2')
    ]}
    let(:mixed_health_states) {[unhealthy('i0', 'north-pole-1')].concat(any_healthy_states)}

    let(:all_unhealthy_states) {[1, 2, 3].map {|i| unhealthy("i#{i}", "eu-#{i}")}}

    let(:health_states) {mixed_health_states}
    let(:elb) {double(:name => 'my_elb', :instances => double(:health => health_states))}
    let(:elbs) { double(AWS::ELB, :load_balancers => {'my_elb' => elb}) }

    before do
      expect(AWS).to receive(:config).at_least(:once) do |config|
        expect(config).to eq(:access_key_id => 'xxx', :secret_access_key => 'yyy', :region => 'zzz')
      end
      allow(AWS::ELB).to receive(:new).and_return(elbs)
    end

    it 'reports total number of healthy instances' do
      expect(plugin.run[:reports].first[:total]).to eq(6)
    end

    it 'reports number of healthy instances per availability zone' do
      expect(plugin.run[:reports].first).to include({'eu-1' => 1, 'eu-2' => 2, 'eu-3' => 3})
    end

    describe ':average' do
      subject {plugin.run[:reports].first[:average]}

      context 'with some healthy instances' do
        it 'reports average number of healthy instance in an availability zone' do
          is_expected.to eq(1.5)
        end
      end

      context 'with no healthy instances' do
        let(:health_states) {all_unhealthy_states}

        it 'reports a zero' do
          is_expected.to eq(0)
        end
      end
    end

    describe ':minimum' do
      subject {plugin.run[:reports].first[:minimum]}

      context 'with some healthy instances' do
        let(:health_states) {any_healthy_states}

        it 'reports minimum number of healthy instance in an availability zone' do
          is_expected.to eq(1)
        end
      end

      context 'with no healthy instances' do
        let(:health_states) {all_unhealthy_states}

        it 'reports a zero' do
          is_expected.to eq(0)
        end
      end
    end

    describe ':zones' do
      subject {plugin.run[:reports].first[:zones]}

      it 'reports total number of known availability zones' do
        is_expected.to eq(4)
      end

      context 'with no healthy zone' do
        let(:health_states) {all_unhealthy_states}

        it 'reports total number of known availability zones' do
          is_expected.to eq(3)
        end
      end
    end

    describe ':healthy_zones' do
      subject {plugin.run[:reports].first[:healthy_zones]}

      it 'reports number of healthy availability zones' do
        is_expected.to eq(3)
      end

      context 'with no healthy instances' do
        let(:health_states) {all_unhealthy_states}

        it 'reports a zero' do
          is_expected.to eq(0)
        end
      end

      context 'with transient zones' do
        let(:health_states) {healthy_and_transient_states}

        it 'reports unknown zones as healthy' do
          is_expected.to eq(2)
        end
      end
    end

    describe ':unhealthy_zones' do
      subject {plugin.run[:reports].first[:unhealthy_zones]}

      it 'reports number of healthy availability zones' do
        is_expected.to eq(1)
      end

      context 'with all healthy zones' do
        let(:health_states) {any_healthy_states}

        it 'reports a zero' do
          is_expected.to eq(0)
        end
      end

      context 'with transient zones' do
        let(:health_states) {healthy_and_transient_states}

        it 'reports a zero' do
          is_expected.to eq(0)
        end
      end
    end

    describe 'logging unhealthy instances' do
      let(:time) { Time.now }

      before { Timecop.freeze(time) }
      after { Timecop.return }

      it 'logs unhealthy instances per ELB and availability zone' do
        2.times { plugin.run }
        expect(File.read('/tmp/elbenwald.log').split("\n")).to eq([
          "[#{time}] [my_elb] [north-pole-1] [i0] [Unhealthy i0]",
          "[#{time}] [my_elb] [eu-1] [i2] [Unhealthy i2]",
          "[#{time}] [my_elb] [eu-1] [i3] [Unhealthy i3]",
          "[#{time}] [my_elb] [eu-2] [i6] [Unhealthy i6]",

          "[#{time}] [my_elb] [north-pole-1] [i0] [Unhealthy i0]",
          "[#{time}] [my_elb] [eu-1] [i2] [Unhealthy i2]",
          "[#{time}] [my_elb] [eu-1] [i3] [Unhealthy i3]",
          "[#{time}] [my_elb] [eu-2] [i6] [Unhealthy i6]",
        ])
      end
    end
  end

end
