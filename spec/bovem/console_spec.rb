# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "spec_helper"

describe Bovem::Console do
  let(:console) { Bovem::Console.new }

  before(:each) do
    ENV["TERM"] = "xterm-256color"
    allow(Kernel).to receive(:puts).and_return(nil)
  end

  describe ".instance" do
    it "should always return the same instance" do
      instance = Bovem::Console.instance
      expect(Bovem::Console.instance).to be(instance)
    end
  end

  describe ".parse_style" do
    it "should correctly parse styles" do
      expect(Bovem::Console.parse_style("red")).to eq("\e[31m")
      expect(Bovem::Console.parse_style("bg_green")).to eq("\e[42m")
      expect(Bovem::Console.parse_style("bright")).to eq("\e[1m")
      expect(Bovem::Console.parse_style("FOO")).to eq("")
      expect(Bovem::Console.parse_style(nil)).to eq("")
      expect(Bovem::Console.parse_style(["A"])).to eq("")
      expect(Bovem::Console.parse_style("-")).to eq("")
    end
  end

  describe ".replace_markers" do
    it "should correct replace markers" do
      expect(Bovem::Console.replace_markers("{mark=red}RED{/mark}")).to eq("\e[31mRED\e[0m")
      expect(Bovem::Console.replace_markers("{mark=red}RED {mark=green}GREEN{/mark}{/mark}")).to eq("\e[31mRED \e[32mGREEN\e[31m\e[0m")
      expect(Bovem::Console.replace_markers("{mark=red}RED {mark=bright-green}GREEN {mark=blue}BLUE{mark=NONE}RED{/mark}{/mark}{/mark}{/mark}")).to eq("\e[31mRED \e[1m\e[32mGREEN \e[34mBLUERED\e[1m\e[32m\e[31m\e[0m")
      expect(Bovem::Console.replace_markers("{mark=bg_red}RED{mark=reset}NORMAL{/mark}{/mark}")).to eq("\e[41mRED\e[0mNORMAL\e[41m\e[0m")
      expect(Bovem::Console.replace_markers("{mark=NONE}RED{/mark}")).to eq("RED")
    end

    it "should clean up markers if requested" do
      expect(Bovem::Console.replace_markers("{mark=red}RED{/mark}", true)).to eq("RED")
    end
  end

  describe ".execute_command" do
    it "should execute a command" do
      expect(Bovem::Console.execute("echo OK")).to eq("OK\n")
    end
  end

  describe ".min_banner_length" do
    it "should return a number" do
      expect(Bovem::Console.min_banner_length).to be_a(Fixnum)
    end
  end

  describe "#initialize" do
    it "should correctly set defaults" do
      expect(console.indentation).to eq(0)
      expect(console.indentation_string).to eq(" ")
    end
  end

  describe "#line_width" do
    it "should return a Fixnum greater than 0" do
      w = console.line_width
      expect(w).to be_a(Fixnum)
      expect(w >= 0).to be_truthy
    end

    it "should use $stdin.winsize if available" do
      expect($stdin).to receive(:winsize)
      console.line_width
    end
  end

  describe "#set_indentation" do
    it "should correctly set indentation" do
      expect(console.indentation).to eq(0)
      console.set_indentation(5)
      expect(console.indentation).to eq(5)
      console.set_indentation(-2)
      expect(console.indentation).to eq(3)
      console.set_indentation(10, true)
      expect(console.indentation).to eq(10)
    end
  end

  describe "#reset_indentation" do
    it "should correctly reset indentation" do
      console.set_indentation(5)
      expect(console.indentation).to eq(5)
      console.reset_indentation
      expect(console.indentation).to eq(0)
    end
  end

  describe "#with_indentation" do
    it "should correctly wrap indentation" do
      console.set_indentation(5)
      expect(console.indentation).to eq(5)

      console.with_indentation(7) do
        expect(console.indentation).to eq(12)
      end
      expect(console.indentation).to eq(5)

      console.with_indentation(3, true) do
        expect(console.indentation).to eq(3)
      end
      expect(console.indentation).to eq(5)
    end
  end

  describe "#wrap" do
    it "should correct wrap text" do
      message = "  ABC__DEF GHI JKL"
      expect(console.wrap(message, 2)).to eq("  ABC__DEF\nGHI\nJKL")
      expect(console.wrap(message, 3)).to eq("  ABC__DEF\nGHI\nJKL")
      expect(console.wrap(message, 4)).to eq("  ABC__DEF\nGHI\nJKL")
      expect(console.wrap(message, 5)).to eq("  ABC__DEF\nGHI\nJKL")
      expect(console.wrap(message, 20)).to eq("  ABC__DEF GHI JKL")

      expect(console.wrap(message, nil)).to eq(message)
      expect(console.wrap(message, -1)).to eq(message)
    end

    it "should work well with #indent" do
      message = "AB CD"
      console.set_indentation(2)
      expect(console.wrap(console.indent(message), 2)).to eq("  AB\n  CD")
    end
  end

  describe "#indent" do
    it "should correctly indent messages" do
      message = "ABC\nCDE"
      console.set_indentation(2)

      expect(console.indent(message)).to eq("  ABC\n  CDE")
      expect(console.indent(message, -1)).to eq(" ABC\n CDE")
      expect(console.indent(message, 1)).to eq("   ABC\n   CDE")
      expect(console.indent(message, true, "D")).to eq("  ABC\nCD  E")

      expect(console.indent(message, 0)).to eq(message)
      expect(console.indent(message, nil)).to eq(message)
      expect(console.indent(message, false)).to eq(message)
      expect(console.indent(message, "A")).to eq(message)
    end
  end

  describe "#format" do
    it "should apply modifications to the message" do
      message = "ABC"
      console.set_indentation(2)
      expect(console.format(message, suffix: "\n", indented: false)).to eq("ABC\n")
      expect(console.format(message, suffix: "A")).to eq("  ABCA")
      expect(console.format(message, suffix: "A", indented: 3)).to eq("     ABCA")
      expect(console.format(message, suffix: "A", indented: 3, wrap: 4)).to eq("     ABCA")
      expect(console.format("{mark=red}ABC{/mark}", plain: true)).to eq("  ABC\n")
    end
  end

  describe "#format_right" do
    it "should correctly align messages" do
      message = "ABCDE"
      extended_message = "ABC\e[AD\e[3mE"
      allow(console).to receive(:line_width).and_return(80)

      expect(console.format_right(message)).to eq("\e[A\e[0G\e[#{75}CABCDE")
      expect(console.format_right(message, width: 10)).to eq("\e[A\e[0G\e[#{-5}CABCDE")
      expect(console.format_right(extended_message)).to eq("\e[A\e[0G\e[#{75}CABC\e[AD\e[3mE")
      expect(console.format_right(message, width: nil, go_up: false)).to eq("\e[0G\e[#{75}CABCDE")
      allow(console).to receive(:line_width).and_return(10)
      expect(console.format_right(message)).to eq("\e[A\e[0G\e[#{5}CABCDE")
    end
  end

  describe "#replace_markers" do
    it "should just forwards to .replace_markers" do
      expect(Bovem::Console).to receive(:replace_markers).with("A", "B")
      console.replace_markers("A", "B")
    end
  end

  describe "#emphasize" do
    it "should correctly emphasize messages" do
      expect(console.emphasize("MSG")).to eq("{mark=bright}MSG{/mark}")
      expect(console.emphasize("MSG", "bright red")).to eq("{mark=bright red}MSG{/mark}")
    end
  end

  describe "#write" do
    it "should call #format" do
      expect(console).to receive(:format).with("A", suffix: "B", indented: "C", wrap: "D", plain: "E")
      console.write("A", suffix: "B", indented: "C", wrap: "D", plain: "E")
    end
  end

  describe "#write_banner_aligned" do
    it "should call #min_banner_length and #format" do
      expect(Bovem::Console).to receive(:min_banner_length).and_return(1)
      expect(console).to receive(:write).with("    A", suffix: "B", indented: "C", wrap: "D", plain: "E", print: "F")
      console.write_banner_aligned("A", suffix: "B", indented: "C", wrap: "D", plain: "E", print: "F")
    end
  end

  describe "#get_banner" do
    it "should correctly format arguments" do
      expect(console.get_banner("LABEL", "red")).to eq("{mark=blue}[{mark=red}LABEL{/mark}]{/mark}")
      expect(console.get_banner("LABEL", "red", full_colored: true)).to eq("{mark=red}[{mark=red}LABEL{/mark}]{/mark}")
      expect(console.get_banner("LABEL", "red", bracket_color: "yellow")).to eq("{mark=yellow}[{mark=red}LABEL{/mark}]{/mark}")
      expect(console.get_banner("LABEL", "red", brackets: nil)).to eq("{mark=blue}{mark=red}LABEL{/mark}{/mark}")
      expect(console.get_banner("LABEL", "red", brackets: "A")).to eq("{mark=blue}A{mark=red}LABEL{/mark}{/mark}")
      expect(console.get_banner("LABEL", "red", brackets: ["A", "B"])).to eq("{mark=blue}A{mark=red}LABEL{/mark}B{/mark}")
    end
  end

  describe "#info" do
    it "should forward everything to #get_banner" do
      expect(console).to receive(:get_banner).with("I", "bright cyan", full_colored: false).at_least(1).and_return("")
      console.info("OK", suffix: "\n", full_colored: false)
      expect(console).to receive(:get_banner).with("I", "bright cyan", full_colored: true).at_least(1).and_return("")
      console.info("OK", suffix: "\n", full_colored: true)
    end

    it "should forward everything to #write" do
      expect(console).to receive(:write).with(/.+/, suffix: "B", indented: 0, wrap: "D", plain: "E", print: false)
      console.info("A", suffix: "B", indented: "C", wrap: "D", plain: "E", print: false)
    end
  end

  describe "#progress" do
    it "should format good list progresses" do
      expect(console.progress(1, 14)).to eq("01/14")
      expect(console.progress(135, 14)).to eq("135/14")
    end

    it "should format good percentage progresses" do
      expect(console.progress(1, 100, type: :percentage)).to eq("  1 %")
      expect(console.progress(33, 100, type: :percentage)).to eq(" 33 %")
      expect(console.progress(1400, 100, type: :percentage)).to eq("1400 %")
      expect(console.progress(50, 70, type: :percentage)).to eq(" 71 %")
      expect(console.progress(50, 70, type: :percentage, precision: 2)).to eq(" 71.43 %")
      expect(console.progress(50, 70, type: :percentage, precision: 3)).to eq(" 71.429 %")
      expect(console.progress(0, 0, type: :percentage)).to eq("100 %")
      expect(console.progress(1, 0, type: :percentage)).to eq("100 %")
      expect(console.progress(0, 100, type: :percentage)).to eq("  0 %")
    end
  end

  describe "#begin" do
    it "should forward everything to #get_banner" do
      expect(console).to receive(:get_banner).with("*", "bright green", full_colored: false).at_least(1).and_return("")
      console.begin("OK", suffix: "\n", full_colored: false)
      expect(console).to receive(:get_banner).with("*", "bright green", full_colored: true).at_least(1).and_return("")
      console.begin("OK", suffix: "\n", full_colored: true)
    end

    it "should forward everything to #write" do
      expect(console).to receive(:write).with(/.+/, suffix: "B", indented: 0, wrap: "D", plain: "E", print: false)
      console.begin("A", suffix: "B", indented: "C", wrap: "D", plain: "E", print: false)
    end
  end

  describe "#warn" do
    it "should forward everything to #get_banner" do
      expect(console).to receive(:get_banner).with("W", "bright yellow", full_colored: false).at_least(1).and_return("")
      console.warn("OK", suffix: "\n", full_colored: false)
      expect(console).to receive(:get_banner).with("W", "bright yellow", full_colored: true).at_least(1).and_return("")
      console.warn("OK", suffix: "\n", full_colored: true)
    end

    it "should forward everything to #write" do
      expect(console).to receive(:write).with(/.+/, suffix: "B", indented: 0, wrap: "D", plain: "E", print: false)
      console.warn("A", suffix: "B", indented: "C", wrap: "D", plain: "E", print: false)
    end
  end

  describe "#error" do
    it "should forward everything to #get_banner" do
      expect(console).to receive(:get_banner).with("E", "bright red", full_colored: false).at_least(1).and_return("")
      console.error("OK", suffix: "\n", full_colored: false)
      expect(console).to receive(:get_banner).with("E", "bright red", full_colored: true).at_least(1).and_return("")
      console.error("OK", suffix: "\n", full_colored: true)
    end

    it "should forward everything to #write" do
      expect(console).to receive(:write).with(/.+/, suffix: "B", indented: 0, wrap: "D", plain: "E", print: false)
      console.error("A", suffix: "B", indented: "C", wrap: "D", plain: "E", print: false)
    end
  end

  describe "#fatal" do
    it "should forward anything to #error" do
      allow(Kernel).to receive(:exit).and_return(true)
      expect(console).to receive(:error).with("A", suffix: "B", indented: "C", wrap: "D", plain: "E", indented_banner: "F", full_colored: "G", print: true)
      console.fatal("A", suffix: "B", indented: "C", wrap: "D", plain: "E", indented_banner: "F", full_colored: "G")
    end

    it "should call abort with the right error code" do
      allow(Kernel).to receive(:exit).and_return(true)

      expect(Kernel).to receive(:exit).with(-1).exactly(2)
      console.fatal("A", suffix: "B", indented: "C", wrap: "D", plain: "E", indented_banner: "F", full_colored: "G", return_code: -1, print: false)
      console.fatal("A", suffix: "B", indented: "C", wrap: "D", plain: "E", indented_banner: "F", full_colored: "G", return_code: "H", print: false)
    end
  end

  describe "#debug" do
    it "should forward everything to #get_banner" do
      expect(console).to receive(:get_banner).with("D", "bright magenta", full_colored: false).at_least(1).and_return("")
      console.debug("OK", suffix: "\n", full_colored: false)
      expect(console).to receive(:get_banner).with("D", "bright magenta", full_colored: true).at_least(1).and_return("")
      console.debug("OK", suffix: "\n", full_colored: true)
    end

    it "should forward everything to #write" do
      expect(console).to receive(:write).with(/.+/, suffix: "B", indented: 0, wrap: "D", plain: "E", print: false)
      console.debug("A", suffix: "B", indented: "C", wrap: "D", plain: "E", print: false)
    end
  end

  describe "#status" do
    it "should get the right status" do
      expect(console.status(:ok, print: false)).to eq({label: " OK ", color: "bright green"})
      expect(console.status(:pass, print: false)).to eq({label: "PASS", color: "bright cyan"})
      expect(console.status(:warn, print: false)).to eq({label: "WARN", color: "bright yellow"})
      expect(console.status(:fail, print: false)).to eq({label: "FAIL", color: "bright red"})
      expect(console.status("NO", print: false)).to eq({label: " OK ", color: "bright green"})
      expect(console.status(nil, print: false)).to eq({label: " OK ", color: "bright green"})
    end

    it "should create the banner" do
      expect(console).to receive(:get_banner).with(" OK ", "bright green").and_return("")
      console.status(:ok)
    end

    it "should format correctly" do
      expect(console).to receive(:format_right).with(/.+/, width: true, go_up: true, plain: false)
      expect(console).to receive(:format).with(/.+/, suffix: "\n", indent: true, wrap: true, plain: false)

      console.status(:ok)
      console.status(:ok, right: false)
    end
  end

  describe "#read" do
    it "should show a prompt" do
      allow($stdin).to receive(:gets).and_return("VALUE\n")

      prompt = "PROMPT"
      expect(Kernel).to receive(:print).with("Please insert a value: ")
      console.read(prompt: true)
      expect(Kernel).to receive(:print).with(prompt + ": ")
      console.read(prompt: prompt)
      expect(Kernel).not_to receive("print")
      console.read(prompt: nil)
    end

    it "should read a value or a default" do
      allow($stdin).to receive(:gets).and_return("VALUE\n")
      expect(console.read(prompt: nil, default_value: "DEFAULT")).to eq("VALUE")
      allow($stdin).to receive(:gets).and_return("\n")
      expect(console.read(prompt: nil, default_value: "DEFAULT")).to eq("DEFAULT")
    end

    it "should return the default value if the user quits" do
      allow($stdin).to receive(:gets).and_raise(Interrupt)
      expect(console.read(prompt: nil, default_value: "DEFAULT")).to eq("DEFAULT")
    end

    it "should validate against an object or array validator" do
      count = 0

      allow($stdin).to receive(:gets) do
        if count == 0
          count += 1
          "2\n"
        else
          raise Interrupt
        end
      end

      expect(console).to receive(:write).with("Sorry, your reply was not understood. Please try again.", false, false).exactly(4)
      count = 0
      console.read(prompt: nil, validator: "A")
      count = 0
      console.read(prompt: nil, validator: "1")
      count = 0
      console.read(prompt: nil, validator: "nil")
      count = 0
      console.read(prompt: nil, validator: ["A", 1])
    end

    it "should validate against an regexp validator" do
      count = 0

      allow($stdin).to receive(:gets) do
        if count == 0 then
          count += 1
          "2\n"
        else
          raise Interrupt
        end
      end

      expect(console).to receive(:write).with("Sorry, your reply was not understood. Please try again.", false, false)
      console.read(prompt: nil, validator: /[abc]/)
    end

    it "should hide echo to the user when the terminal shows echo" do
      expect($stdin).to receive(:noecho).and_return("VALUE")
      console.read(prompt: nil, echo: false)
    end
  end

  describe "#task" do
    it "should not print the message by default" do
      expect(console).not_to receive("begin")
      console.task { :ok }
    end

    it "should print the message and indentate correctly" do
      expect(console).to receive(:begin).with("A", suffix: "B", indented: "C", wrap: "D", plain: "E", indented_banner: "F", full_colored: "G")
      expect(console).to receive(:with_indentation).with("H", "I")
      console.task("A", suffix: "B", indented: "C", wrap: "D", plain: "E", indented_banner: "F", full_colored: "G", block_indentation: "H", block_indentation_absolute: "I") { :ok }
    end

    it "should execute the given block" do
      expect(Bovem::Console).to receive(:foo)
      console.task { Bovem::Console.foo }
    end

    it "should write the correct status" do
      allow(console).to receive(:begin)
      expect(console).to receive(:status).with(:ok, plain: false)
      console.task("OK") { :ok }
      expect(console).to receive(:status).with(:fail, plain: false)
      expect { console.task("") { :fatal }}.to raise_error(SystemExit)
    end

    it "should abort correctly" do
      expect { console.task { [:fatal, -1] }}.to raise_error(SystemExit)
    end
  end
end