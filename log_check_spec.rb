# encoding: utf-8
require File.expand_path("../log_check", __FILE__)

describe LogCheck do
  let(:ignore) { "\\[kenn ich\\]↓\\[kenn ich (auch|gut)\\]" }

  let(:file) do
    path = "/tmp/log_check_test_#{(rand * (2**32)).to_i}"
    File.open(path, "w") do |f|
      f.puts "[kenn ich] Hallo"
      f.puts "[kenn ich auch] Welt!"
      f.puts ""
      f.puts "[kenn ich nicht] Was?"
      f.puts "    "
      f.puts "[kenn ich gut] Huhu"
      f.puts "\t"
      f.puts "what's up?"
    end
    @inode = File.stat(path).ino
    @size = File.stat(path).size
    @lines_to_report = 2
    path
  end

  after do
    File.delete(file)
  end

  shared_examples_for "any run" do
    it "should remember inode and size" do
      plugin.run[:memory].should == {
        :inode => @inode,
        :size => @size
      }
    end

    it "should report the amount of alerted lines" do
      plugin.run[:reports].first[:lines_reported].should == @lines_to_report
    end
  end

  describe "when run for the first time" do
    let(:plugin) do
      LogCheck.new(nil, {}, :log_path => file, :ignore => ignore)
    end

    it_should_behave_like "any run"

    it "should alert lines not matched by any pattern" do
      plugin.run[:alerts].first.should == {
        :subject => "Unrecognized lines in '#{file}'",
        :body => "[kenn ich nicht] Was?\nwhat's up?\n"
      }
    end
  end

  describe "when run for the second time" do
    let(:plugin) do
      File.open(file, "a") do |f|
        f.puts "[kenn ich] Mehr"
        f.puts ""
        f.puts "[kenn ich immer noch nicht] Was?"
        f.puts "    "
        f.puts "[kenn ich] Inhalt"
        f.puts "\t"
        f.puts "what he said?"
      end
      plugin = LogCheck.new(Time.now - 60, {:inode => @inode, :size => @size},
          {:log_path => file, :ignore => ignore})
      @inode = File.stat(file).ino
      @size = File.stat(file).size
      @lines_to_report = 2
      plugin
    end

    it_should_behave_like "any run"

    it "should alert only new lines not matched by any pattern" do
      plugin.run[:alerts].first.should == {
        :subject => "Unrecognized lines in '#{file}'",
        :body => "[kenn ich immer noch nicht] Was?\nwhat he said?\n"
      }
    end

    describe "when inode has changed" do
      let(:rotated_file) { "#{file}.rotated" }
      let(:plugin) do
        plugin = LogCheck.new(Time.now - 60, {:inode => @inode, :size => @size},
          :log_path => file, :ignore => ignore)
        File.rename(file, rotated_file)
        File.open(file, "w") do |f|
          f.puts "Neuer"
          f.puts "[kenn ich] Inhalt"
        end
        @inode = File.stat(file).ino
        @size = File.stat(file).size
        @lines_to_report = 1
        plugin
      end

      after do
        File.delete rotated_file
      end

      it_should_behave_like "any run"

      it "should alert all lines not matched by any pattern regardless of last size" do
        plugin.run[:alerts].first.should == {
          :subject => "Unrecognized lines in '#{file}'",
          :body => "Neuer\n"
        }
      end
    end
  end

  describe "when run for an incomplete file" do
    let(:plugin) do
      LogCheck.new(nil, {}, :log_path => file, :ignore => ignore)
    end

    before do
      File.open(file, "a") do |f|
        f.write "Ich bringe keinen Satz zu En"
      end
    end

    it_should_behave_like "any run"

    it "should memorize the position after the last complete line" do
      plugin.run[:memory][:size].should == @size
    end

    it "should not alert the incomplete line" do
      plugin.run[:alerts].first[:body].should_not =~ /Ich bringe keinen Satz zu En/
    end
  end

  shared_examples_for "an unremarkable run" do
    before do
      # compute @lines_to_report for the first time
      file
      @lines_to_report = 0
    end

    it_should_behave_like "any run"

    it "should not alert anything" do
      plugin.run[:alerts].should be_empty
    end
  end

  describe "when all new lines are expected" do
    let(:plugin) do
      File.open(file, "a") do |f|
        f.puts "[kenn ich] Mehr"
        f.puts ""
        f.puts "    "
        f.puts "\t"
        f.puts "[kenn ich] Inhalt"
      end
      plugin = LogCheck.new(Time.now - 60, {:inode => @inode, :size => @size},
          {:log_path => file, :ignore => ignore})
      @inode = File.stat(file).ino
      @size = File.stat(file).size
      plugin
    end

    it_should_behave_like "an unremarkable run"
  end

  describe "when no new lines were added" do
    let(:plugin) do
      # compute @inode and @size
      file
      LogCheck.new(Time.now - 60, {:inode => @inode, :size => @size},
          {:log_path => file, :ignore => ignore})
    end

    it_should_behave_like "an unremarkable run"
  end
end
