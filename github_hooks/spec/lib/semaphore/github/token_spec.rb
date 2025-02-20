require "spec_helper"

module Semaphore::Github
  RSpec.describe Token do

    let(:new_github_token)           { "new_github_token" }
    let(:failed_authorization_json)  { { "message" => "Not Found" } }
    let(:success_authorization_json) { { "id" => "user_github_id", "token" => new_github_token } }
    let(:expected_path)              { "https://semaphore_client_id:semaphore_secret_id@api.github.com/applications/semaphore_client_id/tokens/user_github_token" }

    before do
      @user = FactoryBot.create(:user_marvinwills, :github_connection)
      @github_account = @user.repo_host_account("github")
      @github_token = @github_account.token
      @token = Token.new(@github_token)

      @response = double("Response", :body => nil)
      @faraday = double(Faraday::Connection, :get => @response, :post => @response)
      allow(Faraday::Connection).to receive(:new) { @faraday }

      allow(App).to receive_messages(github_app_id: "semaphore_client_id", github_secret_id: "semaphore_secret_id")
    end

    describe "#authorized?" do
      context "token is not authorized" do
        before do
          allow(JSON).to receive(:parse) { failed_authorization_json }
        end

        it "returns false" do
          expect(@token.authorized?).to be_falsey
        end
      end

      context "token is authorized" do
        before do
          allow(JSON).to receive(:parse) { success_authorization_json }
        end

        it "returns true" do
          expect(@token.authorized?).to be_truthy
        end
      end
    end

    describe "#reauthorize" do
      context "token is authorized" do
        before do
          allow(JSON).to receive(:parse) { success_authorization_json }
        end

        it "assigns user the new token" do
          @token.reauthorize

          expect(@github_account.reload.token).to eq(new_github_token)
        end
      end

      context "token is not authorized" do
        before do
          allow(JSON).to receive(:parse) { failed_authorization_json }
        end

        it "does not assign new token to user" do
          expect(@token.reauthorize).to be_falsey
          expect(@github_account.reload.token).to eq(@github_token)
        end
      end
    end
  end
end
