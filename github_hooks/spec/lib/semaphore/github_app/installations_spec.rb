require "spec_helper"

module Semaphore::GithubApp
  RSpec.describe Installations do
    describe ".init!" do
      let(:installations_body) { [{ "id" => 111 }, { "id" => 222 }].to_json }

      before do
        allow(Semaphore::GithubApp::Token).to receive(:generate_jwt).and_return("jwt")
        allow(Excon).to receive(:get).and_return(
          instance_double(Excon::Response, :status => 200, :data => { :body => installations_body })
        )
      end

      it "creates every installation and refreshes each" do
        allow(Semaphore::GithubApp::Repositories).to receive(:refresh).and_return(:ok)

        described_class.init!

        expect(GithubAppInstallation.pluck(:installation_id)).to contain_exactly(111, 222)
        expect(Semaphore::GithubApp::Repositories).to have_received(:refresh).with(111)
        expect(Semaphore::GithubApp::Repositories).to have_received(:refresh).with(222)
      end

      it "skips a rate-limited installation without aborting the rest" do
        allow(Rails.logger).to receive(:warn)
        allow(Semaphore::GithubApp::Repositories).to receive(:refresh)
          .with(111).and_raise(LowRateLimitError.new("low", :resets_at => Time.zone.at(1_000_000)))
        allow(Semaphore::GithubApp::Repositories).to receive(:refresh).with(222).and_return(:ok)

        expect { described_class.init! }.not_to raise_error

        expect(GithubAppInstallation.pluck(:installation_id)).to contain_exactly(111, 222)
        expect(Semaphore::GithubApp::Repositories).to have_received(:refresh).with(222)
        expect(Rails.logger).to have_received(:warn).with(/Skipping refresh for installation 111/)
      end

      it "does not swallow non-rate-limit errors" do
        allow(Semaphore::GithubApp::Repositories).to receive(:refresh).with(111).and_raise(StandardError.new("boom"))

        expect { described_class.init! }.to raise_error(StandardError, "boom")
      end
    end
  end
end
