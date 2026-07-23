require "spec_helper"

RSpec.describe RepoHost::Github::ApprovalCommand do
  describe ".present?" do
    # --- the only accepted shape: the whole comment IS the command ---
    it "is true for a bare command" do
      expect(described_class.present?("/sem-approve")).to be(true)
    end

    it "is true for the command with recognized options" do
      expect(described_class.present?("/sem-approve --include-secrets --enable-cache")).to be(true)
    end

    it "tolerates surrounding blank lines" do
      expect(described_class.present?("\n\n/sem-approve\n\n")).to be(true)
    end

    it "tolerates trailing whitespace / a trailing newline" do
      expect(described_class.present?("/sem-approve --include-secrets   \n")).to be(true)
    end

    it "accepts tab-separated options" do
      expect(described_class.present?("/sem-approve\t--include-secrets")).to be(true)
    end

    # --- anything with extra content must NOT trigger ---
    it "is false for the command embedded in prose" do
      expect(described_class.present?("LGTM /sem-approve")).to be(false)
    end

    it "is false when any other non-blank line is present" do
      expect(described_class.present?("please review\n/sem-approve")).to be(false)
      expect(described_class.present?("/sem-approve\nthanks")).to be(false)
    end

    it "is false for two command lines (no multi-line combining)" do
      expect(described_class.present?("/sem-approve --include-secrets\n/sem-approve --enable-cache")).to be(false)
    end

    it "is false inside a blockquote / quoted reply" do
      expect(described_class.present?("> /sem-approve --include-secrets")).to be(false)
    end

    it "is false when indented with spaces or a tab" do
      expect(described_class.present?("    /sem-approve")).to be(false)
      expect(described_class.present?("\t/sem-approve --include-secrets")).to be(false)
    end

    it "is false inside inline code" do
      expect(described_class.present?("`/sem-approve`")).to be(false)
    end

    # --- H2: Markdown code fences of any style/length, nested or unclosed ---
    it "is false inside a triple-backtick fence" do
      expect(described_class.present?("```\n/sem-approve\n```")).to be(false)
    end

    it "is false inside a tilde fence" do
      expect(described_class.present?("~~~\n/sem-approve\n~~~")).to be(false)
    end

    it "is false inside a four-backtick fence containing a triple-backtick line" do
      expect(described_class.present?("````\n```\n/sem-approve --include-secrets\n````")).to be(false)
    end

    it "is false with a mismatched backtick/tilde fence" do
      expect(described_class.present?("```\n/sem-approve\n~~~")).to be(false)
    end

    it "is false with a longer closing fence than the opener" do
      expect(described_class.present?("```\n/sem-approve\n`````")).to be(false)
    end

    it "is false inside an unclosed fence" do
      expect(described_class.present?("```\n/sem-approve --include-secrets")).to be(false)
    end

    # --- H2: HTML comments (single- and multi-line) ---
    it "is false inside a single-line HTML comment" do
      expect(described_class.present?("<!-- /sem-approve --include-secrets -->")).to be(false)
    end

    it "is false inside a multi-line HTML comment" do
      expect(described_class.present?("<!--\n/sem-approve --include-secrets\n-->")).to be(false)
    end

    # --- options / unknown tokens ---
    it "is false with an unknown option" do
      expect(described_class.present?("/sem-approve --nope")).to be(false)
      expect(described_class.present?("/sem-approve --include-secrets --nope")).to be(false)
    end

    it "is false with trailing prose after a valid option" do
      expect(described_class.present?("/sem-approve --include-secrets please")).to be(false)
    end

    it "is false for the empty / nil body" do
      expect(described_class.present?("")).to be(false)
      expect(described_class.present?(nil)).to be(false)
    end
  end

  describe ".options" do
    it "returns the recognized options" do
      expect(described_class.options("/sem-approve --include-secrets --enable-cache"))
        .to contain_exactly("--include-secrets", "--enable-cache")
    end

    it "normalizes the --include-cache alias to --enable-cache" do
      expect(described_class.options("/sem-approve --include-cache")).to eq(["--enable-cache"])
    end

    it "de-duplicates alias + canonical to a single option" do
      expect(described_class.options("/sem-approve --include-cache --enable-cache")).to eq(["--enable-cache"])
    end

    it "returns [] when the comment is not a bare command" do
      expect(described_class.options("please\n/sem-approve --include-secrets")).to eq([])
      expect(described_class.options("/sem-approve --nope")).to eq([])
      expect(described_class.options("```\n/sem-approve --include-secrets\n```")).to eq([])
    end
  end
end
