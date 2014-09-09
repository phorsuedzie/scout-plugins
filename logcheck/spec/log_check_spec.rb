# encoding: utf-8
require_relative "../log_check"

describe LogCheck do
  let(:ignore) { "\\[kenn ich\\]↓\\[kenn ich (auch|gut)\\]" }

  let(:file_contents) do
    [
      "[kenn ich] Hallo",
      "[kenn ich auch] Welt!",
      "",
      "[kenn ich nicht] Was?",
      "    ",
      "[kenn ich gut] Huhu",
      "\t",
      "what's up?",
    ]
  end

  let(:lines_to_report) { 2 }

  let(:file) do
    path = "/tmp/log_check_test_#{(rand * (2**32)).to_i}"
    File.open(path, "w:UTF-8") do |f|
      file_contents.each do |line|
        f.puts line
      end
    end
    @inode = File.stat(path).ino
    @size = File.stat(path).size
    path
  end

  let(:plugin) do
    LogCheck.new(nil, {}, :log_path => file, :ignore => ignore)
  end

  after do
    File.delete(file)
  end

  shared_examples_for "any run" do
    it "should remember inode and size" do
      expect(plugin.run[:memory]).to eq({
        :inode => @inode,
        :size => @size
      })
    end

    it "should report the amount of alerted lines" do
      expect(plugin.run[:reports].first[:lines_reported]).to eq(lines_to_report)
    end
  end

  describe "when run for the first time" do
    it_should_behave_like "any run"

    it "should alert lines not matched by any pattern" do
      expect(plugin.run[:alerts].first).to eq({
        :subject => "Unrecognized lines in '#{file}'",
        :body => "[kenn ich nicht] Was?\nwhat's up?\n"
      })
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
      plugin
    end

    it_should_behave_like "any run"

    it "should alert only new lines not matched by any pattern" do
      expect(plugin.run[:alerts].first).to eq({
        :subject => "Unrecognized lines in '#{file}'",
        :body => "[kenn ich immer noch nicht] Was?\nwhat he said?\n"
      })
    end

    describe "when inode has changed" do
      let(:rotated_file) { "#{file}.rotated" }
      let(:lines_to_report) { 1 }
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
        plugin
      end

      after do
        File.delete rotated_file
      end

      it_should_behave_like "any run"

      it "should alert all lines not matched by any pattern regardless of last size" do
        expect(plugin.run[:alerts].first).to eq({
          :subject => "Unrecognized lines in '#{file}'",
          :body => "Neuer\n"
        })
      end
    end
  end

  describe "when run for an incomplete file" do
    before do
      File.open(file, "a", :encoding => "BINARY") do |f|
        f.write "Ich bringe keinen Satz zu En\xC3"
      end
    end

    it_should_behave_like "any run"

    it "should memorize the position after the last complete line" do
      expect(plugin.run[:memory][:size]).to eq(@size)
    end

    it "should not alert the incomplete line" do
      expect(plugin.run[:alerts].first[:body]).to_not match(/Ich bringe keinen Satz zu En/)
    end

    context "when the incomplete line has been finished" do
      before do
        plugin.run
        plugin.alerts.clear
        File.open(file, "a") do |f|
          f.write "\xB6de\n"
        end
      end

      context "and is not expected" do
        it "should report it" do
          expect(plugin.run[:alerts].first[:body]).to match(/Ich bringe keinen Satz zu Enöde/)
        end
      end

      context "and is expected" do
        let(:ignore) {
          "Ich bringe keinen Satz zu Enöde"
        }

        it "should not report it" do
          expect(plugin.run[:alerts].first[:body]).to_not match(/Ich bringe keinen Satz zu Enöde/)
        end
      end
    end

    context "when the incomplete line has a newline (which is totally unexpected)" do
      before do
        plugin.run
        plugin.alerts.clear
        File.open(file, "a") do |f|
          f.write "\n"
        end
      end

      it "should report it" do
        expect(plugin.run[:alerts].first[:body]).to match(/#{"Ich bringe keinen Satz zu EnÃ".encode('ISO-8859-15')}/)
      end
    end
  end

  shared_examples_for "an unremarkable run" do
    let(:lines_to_report) { 0 }

    it_should_behave_like "any run"

    it "should not alert anything" do
      expect(plugin.run[:alerts]).to be_empty
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

  describe "when ignoring real life patterns" do
    let(:ignore) {
      "\\[notice\\]↓WARNING: Nokogiri was built against↓/home/deploy/\\.bundler/crm/ruby/1\\.9\\.1/gems/resque-1\\.20\\.0/lib/resque/helpers\\.rb:5:in `': \\[DEPRECATION\\] MultiJson\\.engine is deprecated and will be removed in the next major version\\. Use MultiJson\\.adapter instead\\."
    }

    let(:file_contents) do
      [
        "[Fri Jun 08 09:48:31 2012] [notice] SIGUSR1 received. Doing graceful restart",
        "/home/deploy/.bundler/crm/ruby/1.9.1/gems/resque-1.20.0/lib/resque/helpers.rb:5:in `': [DEPRECATION] MultiJson.engine is deprecated and will be removed in the next major version. Use MultiJson.adapter instead.",
        "/home/deploy/.bundler/crm/ruby/1.9.1/gems/resque-1.20.0/lib/resque/helpers.rb:5:in `': [DEPRECATION] MultiJson.engine is deprecated and will be removed in the next major version. Use MultiJson.adapter instead."
      ]
    end

    let(:lines_to_report) { 0 }

    it_should_behave_like "any run"
  end

  context "when finding utf-8 lines with Encoding.default_external=US-ASCII" do
    let(:file_contents) { ["Hällö Böyz!"] }
    let(:ignore) { "z!" }

    before do
      @old_default_external = Encoding.default_external
      Encoding.default_external = Encoding::US_ASCII
    end

    after do
      Encoding.default_external = @old_default_external
    end

    it_should_behave_like "an unremarkable run"
  end

  context "when run with a remaining file size of more than 10MB" do
    let(:file_contents) { ["1234567890\n"] * 1000 * 1000 }
    let(:lines_to_report) { 0 }

    it "should not analyze the contents" do
      # initialize file (uses File.open)
      file
      expect(File).to_not receive(:open)
      plugin.run
    end

    it "should alert the huge amount of log data" do
      expect(plugin.run[:alerts].first).to eq({
        subject: "Too much log data in '#{file}'",
        body: "The file '#{file}' has 10.49 MB of unanalyzed log data. This will be skipped."
      })
    end

    it_should_behave_like "any run"
  end
end
