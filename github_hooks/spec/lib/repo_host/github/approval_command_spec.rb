require "spec_helper"

RSpec.describe RepoHost::Github::ApprovalCommand do
  describe ".present?" do
    it "is true for a bare whole-line command" do
      expect(described_class.present?("/sem-approve")).to be(true)
    end

    it "is false when the command is indented (leading spaces)" do
      expect(described_class.present?("   /sem-approve")).to be(false)
    end

    it "is false when the command is indented with a tab" do
      expect(described_class.present?("\t/sem-approve --include-secrets")).to be(false)
    end

    it "is false for an indented command among other lines (Markdown code block)" do
      expect(described_class.present?("here is how it works:\n\n    /sem-approve\n")).to be(false)
    end

    it "is true when a command line appears among other lines" do
      expect(described_class.present?("please review\n/sem-approve\nthanks")).to be(true)
    end

    it "is false for a command embedded mid-line" do
      expect(described_class.present?("LGTM /sem-approve")).to be(false)
    end

    it "is false inside a blockquote (quoted reply)" do
      expect(described_class.present?("> /sem-approve --include-secrets")).to be(false)
    end

    it "is false inside inline code" do
      expect(described_class.present?("`/sem-approve`")).to be(false)
    end

    it "is false inside a fenced code block" do
      expect(described_class.present?("```\n/sem-approve\n```")).to be(false)
      expect(described_class.present?("~~~\n/sem-approve\n~~~")).to be(false)
    end

    it "is false when an unknown option is present (fails closed)" do
      expect(described_class.present?("/sem-approve --nope")).to be(false)
      expect(described_class.present?("/sem-approve --include-secrets --nope")).to be(false)
    end

    it "is false for trailing prose" do
      expect(described_class.present?("/sem-approve thanks")).to be(false)
    end

    it "is false for the empty / nil body" do
      expect(described_class.present?("")).to be(false)
      expect(described_class.present?(nil)).to be(false)
    end

    it "recognizes a command line after a closed fence" do
      expect(described_class.present?("```\ncode\n```\n/sem-approve")).to be(true)
    end
  end

  describe ".options" do
    it "returns the recognized options on the command line" do
      expect(described_class.options("/sem-approve --include-secrets --enable-cache"))
        .to contain_exactly("--include-secrets", "--enable-cache")
    end

    it "normalizes the --include-cache alias to --enable-cache" do
      expect(described_class.options("/sem-approve --include-cache")).to eq(["--enable-cache"])
    end

    it "collects and de-duplicates options across command lines" do
      expect(described_class.options("/sem-approve --include-secrets\n/sem-approve --include-cache --include-secrets"))
        .to contain_exactly("--include-secrets", "--enable-cache")
    end

    it "returns nothing when an unknown option invalidates the line" do
      expect(described_class.options("/sem-approve --include-secrets --nope")).to eq([])
    end

    it "ignores options that are not on the command line" do
      expect(described_class.options("/sem-approve\n--enable-cache")).to eq([])
    end
  end
end
