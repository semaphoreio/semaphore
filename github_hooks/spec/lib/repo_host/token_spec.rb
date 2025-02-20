require "spec_helper"

RSpec.describe RepoHost::Token do

  let(:repo_host_account) do
    FactoryBot.build(:repo_host_account,
                     :token => "4804c46c4f7536c2a83be0b3d53345d1ff67a041")
  end
  let(:repo_host) { double("repo_host") }

  before { allow(RepoHost::Factory).to receive(:create_repo_host) { repo_host } }

  describe ".valid?" do
    context "token valid" do

      before { allow(repo_host).to receive(:token_valid?).and_return(true) }

      it "returns true" do
        expect(described_class.valid?(repo_host_account)).to eql(true)
      end

    end

    context "token invalid" do

      before { allow(repo_host).to receive(:token_valid?).and_return(false) }

      it "returns false" do
        expect(described_class.valid?(repo_host_account)).to eql(false)
      end

    end
  end

  describe ".revoke_connection" do

    context "operation successfull" do

      before { allow(repo_host).to receive(:revoke_connection).and_return(true) }

      it "returns true" do
        expect(described_class.revoke_connection(repo_host_account)).to eql(true)
      end

    end

    context "operation unsuccessfull" do

      before { allow(repo_host).to receive(:revoke_connection).and_return(false) }

      it "returns false" do
        expect(described_class.revoke_connection(repo_host_account)).to eql(false)
      end

    end
  end
end
