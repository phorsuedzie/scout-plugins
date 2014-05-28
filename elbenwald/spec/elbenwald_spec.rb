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
      plugin.run[:errors].first[:subject].should eq('Please provide name of the ELB')
      plugin.run[:errors].first[:body].should eq('Please provide name of the ELB')
    end
  end

  context 'with AWS credentials path missing' do
    it 'raises an error' do
      plugin = Elbenwald.new(nil, {}, {:elb_name => 'my_elb'})
      plugin.run[:errors].first[:subject].should eq('Please provide a path to AWS configuration')
      plugin.run[:errors].first[:body].should eq('Please provide a path to AWS configuration')
    end
  end

  context 'with error log path missing' do
    it 'raises an error' do
      plugin = Elbenwald.new(nil, {}, {:elb_name => 'my_elb',
          :aws_credentials_path => '/tmp/elbenwald.yml'})
      plugin.run[:errors].first[:subject].should eq('Please provide a path error log')
      plugin.run[:errors].first[:body].should eq('Please provide a path error log')
    end
  end

  context 'with correct options' do
    def mock_instance_health(options)
      health = {:instance => double(:id => options[:id], :availability_zone => options[:az])}
      if options[:healthy]
        health[:state] = 'InService'
      else
        health[:description] = "Unhealthy #{options[:id]}"
      end
      health
    end

    let :plugin do
      Elbenwald.new(nil, {}, :elb_name => 'my_elb', :aws_credentials_path => '/tmp/elbenwald.yml',
          :error_log_path => '/tmp/elbenwald.log')
    end

    let :elb do
      double(:name => 'my_elb', :instances => double(:health => [
        mock_instance_health(:id => 'i0', :az => 'north-pole-1', :healthy => false),

        mock_instance_health(:id => 'i1', :az => 'eu-1', :healthy => true),
        mock_instance_health(:id => 'i2', :az => 'eu-1', :healthy => false),
        mock_instance_health(:id => 'i3', :az => 'eu-1', :healthy => false),

        mock_instance_health(:id => 'i4', :az => 'eu-2', :healthy => true),
        mock_instance_health(:id => 'i5', :az => 'eu-2', :healthy => true),
        mock_instance_health(:id => 'i6', :az => 'eu-2', :healthy => false),

        mock_instance_health(:id => 'i7', :az => 'eu-3', :healthy => true),
        mock_instance_health(:id => 'i8', :az => 'eu-3', :healthy => true),
        mock_instance_health(:id => 'i9', :az => 'eu-3', :healthy => true),
      ]))
    end

    let(:elbs) { double(AWS::ELB, :load_balancers => {'my_elb' => elb}) }

    before do
      AWS.should_receive(:config).at_least(:once) do |config|
        config.should eq(:access_key_id => 'xxx', :secret_access_key => 'yyy', :region => 'zzz')
      end
      AWS::ELB.stub(:new).and_return(elbs)
    end

    it 'reports total number of healthy instances' do
      plugin.run[:reports].first[:total].should eq(6)
    end

    it 'reports number of healthy instances per availability zone' do
      plugin.run[:reports].first.should include({'eu-1' => 1, 'eu-2' => 2, 'eu-3' => 3})
    end

    describe ':average' do
      context 'with some healthy instances' do
        it 'reports average number of healthy instance in an availability zone' do
          plugin.run[:reports].first[:average].should eq(1.5)
        end
      end

      context 'with no healthy instances' do
        let :elb do
          double(:name => 'my_elb', :instances => double(:health => [
            mock_instance_health(:id => 'i1', :az => 'eu-1', :healthy => false),
            mock_instance_health(:id => 'i2', :az => 'eu-2', :healthy => false),
            mock_instance_health(:id => 'i3', :az => 'eu-3', :healthy => false),
          ]))
        end

        it 'reports a zero' do
          plugin.run[:reports].first[:average].should eq(0)
        end
      end
    end

    describe ':minimum' do
      context 'with some healthy instances' do
        let :elb do
          double(:name => 'my_elb', :instances => double(:health => [
            mock_instance_health(:id => 'i1', :az => 'eu-1', :healthy => true),
            mock_instance_health(:id => 'i2', :az => 'eu-1', :healthy => false),
            mock_instance_health(:id => 'i3', :az => 'eu-1', :healthy => false),

            mock_instance_health(:id => 'i4', :az => 'eu-2', :healthy => true),
            mock_instance_health(:id => 'i5', :az => 'eu-2', :healthy => true),
            mock_instance_health(:id => 'i6', :az => 'eu-2', :healthy => false),

            mock_instance_health(:id => 'i7', :az => 'eu-3', :healthy => true),
            mock_instance_health(:id => 'i8', :az => 'eu-3', :healthy => true),
            mock_instance_health(:id => 'i9', :az => 'eu-3', :healthy => true),
          ]))
        end

        it 'reports minimum number of healthy instance in an availability zone' do
          plugin.run[:reports].first[:minimum].should eq(1)
        end
      end

      context 'with no healthy instances' do
        let :elb do
          double(:name => 'my_elb', :instances => double(:health => [
            mock_instance_health(:id => 'i1', :az => 'eu-1', :healthy => false),
            mock_instance_health(:id => 'i2', :az => 'eu-2', :healthy => false),
            mock_instance_health(:id => 'i3', :az => 'eu-3', :healthy => false),
          ]))
        end

        it 'reports a zero' do
          plugin.run[:reports].first[:minimum].should eq(0)
        end
      end
    end

    describe 'logging unhealthy instances' do
      let(:time) { Time.now }

      before { Timecop.freeze(time) }
      after { Timecop.return }

      it 'logs unhealthy instances per ELB and availability zone' do
        2.times { plugin.run }
        File.read('/tmp/elbenwald.log').split("\n").should eq([
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
