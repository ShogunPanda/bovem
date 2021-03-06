# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "spec_helper"

describe Bovem::Shell do
  let(:shell) { Bovem::Shell.new }
  let(:temp_file_1) { "/tmp/bovem-test-1-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:temp_file_2) { "/tmp/bovem-test-2-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:temp_file_3) { "/tmp/bovem-test-3-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:temp_dir_1) { "/tmp/bovem-test-dir-1-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:temp_dir_2) { "/tmp/bovem-test-dir-2-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }

  before(:each) do
    allow(Kernel).to receive(:puts).and_return(nil)
  end

  describe ".instance" do
    it "should always return the same instance" do
      instance = Bovem::Shell.instance
      expect(Bovem::Shell.instance).to be(instance)
    end
  end

  describe "#initialize" do
    it "should correctly set defaults" do
      expect(shell.console).to eq(Bovem::Console.instance)
    end
  end

  describe "#run" do
    before(:each) do
      allow(::Open4).to receive(:popen4) do |_, _, _, _| OpenStruct.new(exitstatus: 0) end
    end

    it "should show a message" do
      expect(shell.console).to receive("begin").with("MESSAGE")
      shell.run("echo OK", "MESSAGE", show_exit: false)
      expect(shell.console).not_to receive("begin").with("MESSAGE")
      shell.run("echo OK", show_exit: false)
    end

    it "should print the command line" do
      expect(shell.console).to receive("info").with("Running command: {mark=bright}\"echo OK\"{/mark}...")
      shell.run("echo OK", show_exit: true, show_command: true)
    end

    it "should only print the command if requested to" do
      expect(shell.console).to receive("warn").with("Will run command: {mark=bright}\"echo OK\"{/mark}...")
      expect(::Open4).not_to receive("popen4")
      shell.run("echo OK", run: false)
    end

    it "should show a exit message" do
      i = -1
      allow(::Open4).to receive(:popen4) do |_, _, _, _|
        i += 1
        OpenStruct.new(exitstatus: i)
      end

      expect(shell.console).to receive(:status).with(:ok)
      shell.run("echo OK", show_exit: true, fatal_errors: false)
      expect(shell.console).to receive(:status).with(:fail)
      shell.run("echo1 OK", show_exit: true, fatal_errors: false)
    end

    it "should print output" do
      expect(Kernel).to receive("print").with("OK\n")

      stdout = Object.new
      allow(stdout).to receive(:each_line).and_yield("OK\n")
      allow(::Open4).to receive(:popen4).and_yield(nil, nil, stdout, nil).and_return(OpenStruct.new(exitstatus: 0))

      shell.run("echo OK", show_output: true)
    end

    it "should raise a exception for failures" do
      allow(::Open4).to receive(:popen4) {|_, _, _, _| OpenStruct.new(exitstatus: 1) }
      expect { shell.run("echo1 OK", fatal_errors: false) }.not_to raise_error
      expect { shell.run("echo1 OK") }.to raise_error(SystemExit)
    end
  end

  describe "#check" do
    it "executes all tests" do
      expect(shell.check("/", :read, :dir)).to be_truthy
      expect(shell.check("/dev/null", :write)).to be_truthy
      expect(shell.check("/bin/sh", :execute, :exec)).to be_truthy
      expect(shell.check("/", :read, :directory)).to be_truthy
      expect(shell.check("/", :writable?, :directory?)).to be_falsey
    end

    it "returns false when some tests are invalid" do
      expect(shell.check("/", :read, :none)).to be_falsey
    end
  end

  describe "#delete" do
    it "should delete files" do
      File.unlink(temp_file_1) if File.exists?(temp_file_1)
      File.open(temp_file_1, "w") {|f| f.write("OK") }

      expect(File.exists?(temp_file_1)).to be_truthy
      expect(shell.delete(temp_file_1, show_errors: false)).to be_truthy
      expect(File.exists?(temp_file_1)).to be_falsey
      File.unlink(temp_file_1) if File.exists?(temp_file_1)
    end

    it "should only print the list of files" do
      expect(shell.console).to receive(:warn).with("Will remove file(s):")
      expect(FileUtils).not_to receive(:rm_r)
      expect(shell.delete(temp_file_1, run: false)).to be_truthy
    end

    it "should complain about non existing files" do
      expect(shell.console).to receive(:error).with("Cannot remove following non existent file: {mark=bright}#{temp_file_1}{/mark}")
      expect(shell.delete(temp_file_1, fatal_errors: false)).to be_falsey
    end

    it "should complain about non writeable files" do
      expect(shell.console).to receive(:error).with("Cannot remove following non writable file: {mark=bright}/dev/null{/mark}")
      expect(shell.delete("/dev/null", fatal_errors: false)).to be_falsey
    end

    it "should complain about other exceptions" do
      allow(FileUtils).to receive(:rm_r).and_raise(ArgumentError.new("ERROR"))
      expect(shell.console).to receive(:error).with("Cannot remove following file(s):")
      expect(shell.console).to receive(:write).at_least(2)
      expect(shell.delete("/dev/null", show_errors: true, fatal_errors: false)).to be_falsey
    end

    describe "should exit when requested to" do
      it "by calling :fatal" do
        expect(shell.console).to receive(:fatal).with("Cannot remove following non writable file: {mark=bright}/dev/null{/mark}")
        expect(shell.delete("/dev/null")).to be_falsey
      end

      it "by calling Kernel#exit" do
        allow(FileUtils).to receive(:rm_r).and_raise(ArgumentError.new("ERROR"))
        expect(Kernel).to receive(:exit).with(-1)
        expect(shell.delete("/dev/null", show_errors: true, fatal_errors: true)).to be_falsey
      end
    end
  end

  describe "#copy_or_move" do
    before(:each) do
      FileUtils.rm_r(temp_file_1) if File.exists?(temp_file_1)
      FileUtils.rm_r(temp_file_2) if File.exists?(temp_file_2)
      FileUtils.rm_r(temp_file_3) if File.exists?(temp_file_3)
      FileUtils.rm_r(temp_dir_1) if File.exists?(temp_dir_1)
      FileUtils.rm_r(temp_dir_2) if File.exists?(temp_dir_2)
    end

    after(:each) do
      FileUtils.rm_r(temp_file_1) if File.exists?(temp_file_1)
      FileUtils.rm_r(temp_file_2) if File.exists?(temp_file_2)
      FileUtils.rm_r(temp_file_3) if File.exists?(temp_file_3)
      FileUtils.rm_r(temp_dir_1) if File.exists?(temp_dir_1)
      FileUtils.rm_r(temp_dir_2) if File.exists?(temp_dir_2)
    end

    it "should copy a file" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :copy)).to eq(true)
      expect(File.exists?(temp_file_1)).to be_truthy
      expect(File.exists?(temp_file_2)).to be_truthy
    end

    it "should move a file" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :move, true)).to eq(true)
      expect(File.exists?(temp_file_1)).to be_falsey
      expect(File.exists?(temp_file_2)).to be_truthy
    end

    it "should copy multiple entries" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      File.open(temp_file_2, "w") {|f| f.write("OK") }
      shell.create_directories(temp_dir_1)
      File.open(temp_dir_1 + "/temp", "w") {|f| f.write("OK") }

      expect(shell.send(:copy_or_move, [temp_file_1, temp_file_2, temp_dir_1], temp_dir_2, :copy)).to be_truthy
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_file_1))).to be_truthy
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_file_2))).to be_truthy
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_dir_1))).to be_truthy
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_dir_1) + "/temp")).to be_truthy
    end

    it "should move multiple entries" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      File.open(temp_file_2, "w") {|f| f.write("OK") }
      shell.create_directories(temp_dir_1)
      File.open(temp_dir_1 + "/temp", "w") {|f| f.write("OK") }

      expect(shell.send(:copy_or_move, [temp_file_1, temp_file_2, temp_dir_1], temp_dir_2, :move, true)).to be_truthy
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_file_1))).to be_truthy
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_file_2))).to be_truthy
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_dir_1))).to be_truthy
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_dir_1) + "/temp")).to be_truthy
      expect(File.exists?(temp_file_1)).to be_falsey
      expect(File.exists?(temp_file_2)).to be_falsey
      expect(File.exists?(temp_dir_1)).to be_falsey
      expect(File.exists?(temp_dir_1 + "/temp")).to be_falsey
    end

    it "should complain about non existing source" do
      expect(shell.console).to receive(:error).with("Cannot copy non existent file {mark=bright}#{temp_file_1}{/mark}.")
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :copy, true, false, false)).to be_falsey

      expect(shell.console).to receive(:error).with("Cannot move non existent file {mark=bright}#{temp_file_1}{/mark}.")
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :move, true, false, false)).to be_falsey
    end

    it "should not copy a file to a path which is currently a directory" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      shell.create_directories(temp_file_2)

      expect(shell.console).to receive(:error).with("Cannot copy file {mark=bright}#{temp_file_1}{/mark} to {mark=bright}#{temp_file_2}{/mark} because it is currently a directory.")
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :copy, true, false, false)).to be_falsey

      expect(shell.console).to receive(:error).with("Cannot move file {mark=bright}#{temp_file_1}{/mark} to {mark=bright}#{temp_file_2}{/mark} because it is currently a directory.")
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :move, true, false, false)).to be_falsey
    end

    it "should create the parent directory if needed" do
      expect(shell.check(temp_dir_1, :dir)).to be_falsey

      expect(shell).to receive(:create_directories).exactly(2)
      expect(shell.send(:copy_or_move, temp_file_1, temp_dir_1 + "/test-1", :copy)).to be_falsey
      expect(shell.send(:copy_or_move, temp_file_1, temp_dir_1 + "/test-1", :move)).to be_falsey
    end

    it "should only print the list of files" do
      expect(FileUtils).not_to receive(:cp_r)
      expect(FileUtils).not_to receive(:mv)

      expect(shell.console).to receive(:warn).with("Will copy a file:")
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :copy, false)).to be_truthy
      expect(shell.console).to receive(:warn).with("Will copy following entries:")
      expect(shell.send(:copy_or_move, [temp_file_1, temp_file_2], temp_dir_1, :copy, false)).to be_truthy

      expect(shell.console).to receive(:warn).with("Will move a file:")
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :move, false)).to be_truthy
      expect(shell.console).to receive(:warn).with("Will move following entries:")
      expect(shell.send(:copy_or_move, [temp_file_1, temp_file_2], temp_dir_1, :move, false)).to be_truthy
    end

    it "should complain about non writeable parent directory" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }

      expect(shell.console).to receive(:error).with("Cannot copy file {mark=bright}#{temp_file_1}{/mark} to non writable directory {mark=bright}/dev{/mark}.", suffix: "\n", indented: 5)
      expect(shell.send(:copy_or_move, temp_file_1, "/dev/bovem", :copy, true, true, false)).to be_falsey

      expect(shell.console).to receive(:error).with("Cannot move file {mark=bright}#{temp_file_1}{/mark} to non writable directory {mark=bright}/dev{/mark}.", suffix: "\n", indented: 5)
      expect(shell.send(:copy_or_move, temp_file_1, "/dev/bovem", :move, true, true, false)).to be_falsey
    end

    it "should complain about other exceptions" do
      allow(FileUtils).to receive(:cp_r).and_raise(ArgumentError.new("ERROR"))
      allow(FileUtils).to receive(:mv).and_raise(ArgumentError.new("ERROR"))
      File.open(temp_file_1, "w") {|f| f.write("OK") }

      expect(shell.console).to receive(:error).with("Cannot copy file {mark=bright}#{temp_file_1}{/mark} to directory {mark=bright}#{File.dirname(temp_file_2)}{/mark} due to this error: [ArgumentError] ERROR.", suffix: "\n", indented: 5)
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :copy, true, true, false)).to be_falsey

      expect(shell.console).to receive(:error).with("Cannot move file {mark=bright}#{temp_file_1}{/mark} to directory {mark=bright}#{File.dirname(temp_file_2)}{/mark} due to this error: [ArgumentError] ERROR.", suffix: "\n", indented: 5)
      expect(shell.send(:copy_or_move, temp_file_1, temp_file_2, :move, true, true, false)).to be_falsey
    end

    describe "should exit when requested to" do
      it "by calling :fatal" do
        allow(FileUtils).to receive(:cp_r).and_raise(ArgumentError.new("ERROR"))
        allow(FileUtils).to receive(:mv).and_raise(ArgumentError.new("ERROR"))
        allow(Kernel).to receive(:exit).and_return(true)

        File.open(temp_file_1, "w") {|f| f.write("OK") }
        File.open(temp_file_2, "w") {|f| f.write("OK") }

        expect(shell.console).to receive(:fatal).with("Cannot copy file {mark=bright}#{temp_file_1}{/mark} to directory {mark=bright}/dev{/mark} due to this error: [ArgumentError] ERROR.", suffix: "\n", indented: 5)
        expect(shell.send(:copy_or_move, temp_file_1, "/dev/bovem", :copy, true, true, true)).to be_falsey

        expect(shell.console).to receive(:fatal).with("Cannot move file {mark=bright}#{temp_file_1}{/mark} to directory {mark=bright}/dev{/mark} due to this error: [ArgumentError] ERROR.", suffix: "\n", indented: 5)
        expect(shell.send(:copy_or_move, temp_file_1, "/dev/bovem", :move, true, true, true)).to be_falsey

        expect(shell.console).to receive(:error).with("Cannot copy following entries to {mark=bright}/dev{/mark}:")
        expect(shell.send(:copy_or_move, [temp_file_1, temp_file_2], "/dev", :copy, true, true, true)).to be_falsey

        expect(shell.console).to receive(:error).with("Cannot move following entries to {mark=bright}/dev{/mark}:")
        expect(shell.send(:copy_or_move, [temp_file_1, temp_file_2], "/dev", :move, true, true, true)).to be_falsey
      end

      it "by calling Kernel#exit" do
        File.open(temp_file_1, "w") {|f| f.write("OK") }
        File.open(temp_file_2, "w") {|f| f.write("OK") }

        expect(Kernel).to receive(:exit).with(-1).exactly(4).and_return(true)
        expect(shell.send(:copy_or_move, temp_file_1, "/dev/bovem", :copy, true, false, true)).to be_falsey
        expect(shell.send(:copy_or_move, [temp_file_1, temp_file_2], "/dev", :copy, true, false, true)).to be_falsey
        expect(shell.send(:copy_or_move, temp_file_1, "/dev/bovem", :move, true, false, true)).to be_falsey
        expect(shell.send(:copy_or_move, [temp_file_1, temp_file_2], "/dev", :move, true, false, true)).to be_falsey
      end
    end
  end

  describe "#copy" do
    it "should forward everything to #copy_or_move" do
      expect(shell).to receive(:copy_or_move).with("A", "B", operation: :copy, run: "C", show_errors: "D", fatal_errors: "E")
      shell.copy("A", "B", run: "C", show_errors: "D", fatal_errors: "E")
    end
  end

  describe "#move" do
    it "should forward everything to #copy_or_move" do
      expect(shell).to receive(:copy_or_move).with("A", "B", operation: :move, run: "C", show_errors: "D", fatal_errors: "E")
      shell.move("A", "B", run: "C", show_errors: "D", fatal_errors: "E")
    end
  end

  describe "#within_directory" do
    let(:target){ File.expand_path("~") }

    it "should execute block in other directory and return true" do
      dir = ""

      shell.within_directory(target) do
        expect(Dir.pwd).to eq(target)
        dir = "OK"
      end

      expect(dir).to eq("OK")
    end

    it "should change and restore directory" do
      owd = Dir.pwd

      shell.within_directory(target) do
        expect(Dir.pwd).to eq(target)
      end

      expect(Dir.pwd).to eq(owd)
    end

    it "should change but not restore directory" do
      owd = Dir.pwd

      shell.within_directory(target, restore: false) do
        expect(Dir.pwd).to eq(target)
      end

      expect(Dir.pwd).not_to eq(owd)
    end

    it "should show messages" do
      expect(shell.console).to receive(:info).with(/Moving (.*)into directory \{mark=bright\}(.+)\{\/mark\}/).exactly(2)
      shell.within_directory(target, show_messages: true) { "OK" }
    end

    it "should return false and not execute code in case of invalid directory" do
      dir = ""

      expect(shell.within_directory("/invalid") { dir = "OK" }).to be_falsey
      expect(dir).to eq("")

      allow(Dir).to receive(:chdir).and_raise(ArgumentError)
      expect(shell.within_directory("/") { true }).to be_falsey

      allow(Dir).to receive(:chdir)
      allow(Dir).to receive(:pwd).and_return("/invalid")
      expect(shell.within_directory("/") { true }).to be_falsey
    end
  end

  describe "#create_directories" do
    before(:each) do
      FileUtils.rm_r(temp_file_1) if File.exists?(temp_file_1)
      FileUtils.rm_r(temp_file_2) if File.exists?(temp_file_2)
      FileUtils.rm_r(temp_file_3) if File.exists?(temp_file_3)
      FileUtils.rm_r(temp_dir_1) if File.exists?(temp_dir_1)
      FileUtils.rm_r(temp_dir_2) if File.exists?(temp_dir_2)
    end

    after(:each) do
      FileUtils.rm_r(temp_file_1) if File.exists?(temp_file_1)
      FileUtils.rm_r(temp_file_2) if File.exists?(temp_file_2)
      FileUtils.rm_r(temp_file_3) if File.exists?(temp_file_3)
      FileUtils.rm_r(temp_dir_1) if File.exists?(temp_dir_1)
      FileUtils.rm_r(temp_dir_2) if File.exists?(temp_dir_2)
    end

    it "should create directory" do
      expect(shell.create_directories([temp_dir_1, temp_dir_2])).to be_truthy
      expect(shell.check(temp_dir_1, :directory)).to be_truthy
      expect(shell.check(temp_dir_2, :directory)).to be_truthy
    end

    it "should only print the list of files" do
      expect(shell.console).to receive(:warn).with("Will create directories:")
      expect(FileUtils).not_to receive(:mkdir_p)
      expect(shell.create_directories(temp_file_1, run: false)).to be_truthy
    end

    it "should complain about directory already existing" do
      shell.create_directories(temp_dir_1, fatal_errors: false)
      expect(shell.console).to receive(:error).with("The directory {mark=bright}#{temp_dir_1}{/mark} already exists.")
      expect(shell.create_directories(temp_dir_1, show_errors: true, fatal_errors: false)).to be_falsey
    end

    it "should complain about paths already existing as a file." do
      File.open(temp_file_1, "w") {|f| f.write("OK") }

      expect(shell.console).to receive(:error).with("Path {mark=bright}#{temp_file_1}{/mark} is currently a file.")
      expect(shell.create_directories(temp_file_1, show_errors: true, fatal_errors: false)).to be_falsey
    end

    it "should complain about non writable parents" do
      expect(shell.console).to receive(:error).with("Cannot create following directory due to permission denied: {mark=bright}/dev/bovem{/mark}.")
      expect(shell.create_directories("/dev/bovem", show_errors: true, fatal_errors: false)).to be_falsey
    end

    it "should complain about other exceptions" do
      allow(FileUtils).to receive(:mkdir_p).and_raise(ArgumentError.new("ERROR"))
      expect(shell.console).to receive(:error).with("Cannot create following directories:")
      expect(shell.console).to receive(:write).at_least(2)
      expect(shell.create_directories(temp_dir_1, show_errors: true, fatal_errors: false)).to be_falsey
    end

    describe "should exit when requested to" do
      it "by calling :fatal" do
        expect(shell.console).to receive(:fatal).with("Path {mark=bright}/dev/null{/mark} is currently a file.")
        expect(shell.create_directories("/dev/null")).to be_falsey
      end

      it "by calling Kernel#exit" do
        allow(FileUtils).to receive(:mkdir_p).and_raise(ArgumentError.new("ERROR"))
        expect(Kernel).to receive(:exit).with(-1)
        expect(shell.create_directories(temp_dir_1, show_errors: true, fatal_errors: true)).to be_falsey
      end
    end
  end

  describe "#find" do
    let(:root) {File.expand_path(File.dirname(__FILE__) + "/../../") }

    it "it should return [] for invalid or empty directories" do
      expect(shell.find("/invalid", patterns: /rb/)).to eq([])
    end

    it "it should return every file for empty patterns" do
      files = []

      Find.find(root) do |file|
        files << file
      end

      expect(shell.find(root, patterns: nil)).to eq(files)
    end

    it "should find files basing on pattern" do
      files = []

      Find.find(root + "/lib/bovem/") do |file|
        files << file if !File.directory?(file)
      end

      expect(shell.find(root, patterns: /lib\/bovem\/.+rb/)).to eq(files)
      expect(shell.find(root, patterns: /lib\/BOVEM\/.+rb/)).to eq(files)
      expect(shell.find(root, patterns: "lib\/bovem/")).to eq(files)
      expect(shell.find(root, patterns: /lib\/BOVEM\/.+rb/, case_sensitive: true)).to eq([])
    end

    it "should find files basing on extension" do
      files = []

      Find.find(root + "/lib/bovem/") do |file|
        files << file if !File.directory?(file)
      end

      expect(shell.find(root + "/lib/bovem", patterns: /rb/, extension_only: true)).to eq(files)
      expect(shell.find(root + "/lib/bovem", patterns: /bovem/, extension_only: true)).to eq([])
      expect(shell.find(root + "/lib/bovem", patterns: "RB", extension_only: true, case_sensitive: true)).to eq([])
    end

    it "should filter files basing using a block" do
      files = []

      Find.find(root + "/lib/bovem/") do |file|
        files << file if !File.directory?(file)
      end

      expect(shell.find(root + "/lib/bovem", patterns: /rb/, extension_only: true) { |file|
        !File.directory?(file)
      }).to eq(files)
      expect(shell.find(root + "/lib/bovem", patterns: /bovem/, extension_only: true) { |file|
        false
      }).to eq([])
    end
  end
end