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

  context 'with no AWS credentials path missing' do
    it 'raises an error' do
      plugin = Elbenwald.new(nil, {}, {})
      plugin.run[:errors].first[:subject].should eq('Please provide a path to AWS configuration')
      plugin.run[:errors].first[:body].should eq('Please provide a path to AWS configuration')
    end
  end

  context 'with error log path missing' do
    it 'raises an error' do
      plugin = Elbenwald.new(nil, {}, {:aws_credentials_path => '/tmp/elbenwald.yml'})
      plugin.run[:errors].first[:subject].should eq('Please provide a path error log')
      plugin.run[:errors].first[:body].should eq('Please provide a path error log')
    end
  end

  context 'with correct options' do
    def mock_instance_health(options)
      health = {:instance => mock(:id => options[:id], :availability_zone => options[:az])}
      if options[:healthy]
        health[:state] = 'InService'
      else
        health[:description] = "Unhealthy #{options[:id]}"
      end
      health
    end

    let :plugin do
      Elbenwald.new(nil, {}, :aws_credentials_path => '/tmp/elbenwald.yml',
          :error_log_path => '/tmp/elbenwald.log')
    end

    let :load_balancer1 do
      mock(:name => 'ELB1', :instances => mock(:health => [
        mock_instance_health(:id => 'i1', :az => 'eu-1', :healthy => true),
        mock_instance_health(:id => 'i2', :az => 'eu-1', :healthy => false),
        mock_instance_health(:id => 'i3', :az => 'eu-1', :healthy => false),

        mock_instance_health(:id => 'i5', :az => 'eu-2', :healthy => true),
        mock_instance_health(:id => 'i6', :az => 'eu-2', :healthy => true),
        mock_instance_health(:id => 'i7', :az => 'eu-2', :healthy => false),
      ]))
    end

    let :load_balancer2 do
      mock(:name => 'ELB2', :instances => mock(:health => [
        mock_instance_health(:id => 'i8', :az => 'eu-3', :healthy => true),
        mock_instance_health(:id => 'i9', :az => 'eu-3', :healthy => true),
        mock_instance_health(:id => 'i0', :az => 'eu-3', :healthy => true),
      ]))
    end

    let(:elb) { mock(AWS::ELB, :load_balancers => [load_balancer1, load_balancer2]) }

    before do
      AWS.should_receive(:config).at_least(:once) do |config|
        config.should eq(:access_key_id => 'xxx', :secret_access_key => 'yyy', :region => 'zzz')
      end

      AWS::ELB.stub(:new).and_return(elb)
    end

    it 'reports number of healthy instances per ELB and availability zone' do
      plugin.run[:reports].first.should eq({
        'ELB1-eu-1' => 1,
        'ELB1-eu-2' => 2,
        'ELB2-eu-3' => 3,
      })
    end

    it 'logs unhealthy instances per ELB and availability zone' do
      Timecop.freeze
      2.times { plugin.run }
      File.read('/tmp/elbenwald.log').split("\n").should eq([
        '[0000-01-01 00:00:00 +0100] [ELB1] [eu-1] [i2] [Unhealthy i2]',
        '[0000-01-01 00:00:00 +0100] [ELB1] [eu-1] [i3] [Unhealthy i3]',
        '[0000-01-01 00:00:00 +0100] [ELB1] [eu-2] [i7] [Unhealthy i7]',

        '[0000-01-01 00:00:00 +0100] [ELB1] [eu-1] [i2] [Unhealthy i2]',
        '[0000-01-01 00:00:00 +0100] [ELB1] [eu-1] [i3] [Unhealthy i3]',
        '[0000-01-01 00:00:00 +0100] [ELB1] [eu-2] [i7] [Unhealthy i7]',
      ])
    end
  end

end
