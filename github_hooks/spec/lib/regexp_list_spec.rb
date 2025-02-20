require "spec_helper"

RSpec.describe RegexpList do
  before do
    @raw_list = "master\r\nhotfix*"
    @regexp_list = RegexpList.new(@raw_list)
  end

  describe "initialization" do
    context "when some regexps are not valid" do
      it "doesn't raise error" do
        expect { RegexpList.new("*bad-regexp*") }.not_to raise_error
      end
    end
  end

  describe "#valid?" do
    context "when all regexps are valid" do
      it "returns true" do
        regexp_list = RegexpList.new("master\r\rhotfix.*")
        expect(regexp_list.valid?).to eql(true)
      end
    end

    context "when some regexps are not valid" do
      it "returns false" do
        regexp_list = RegexpList.new("*bad-regexp*")
        expect(regexp_list.valid?).to eql(false)
      end
    end
  end

  describe "#matches?" do
    it "matches string against regexps from the list" do
      expect(@regexp_list.matches?("master")).to eql(true)
      expect(@regexp_list.matches?("hotfix-12")).to eql(true)
      expect(@regexp_list.matches?("development")).to eql(false)
    end

    context "when raw list is nil" do
      it "doesn't raise exception" do
        expect { RegexpList.new(nil).matches?("master") }.not_to raise_error
      end
    end
  end
end
