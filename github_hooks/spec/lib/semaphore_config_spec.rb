require "spec_helper"

RSpec.describe SemaphoreConfig do

  describe "reading values from configuration env" do
    context "when the config is exported" do
      it "returns its value" do
        expect(SemaphoreConfig.insights_port).to eq("2376")
      end
    end

    context "when the config is not exported" do
      context "when the config is aviable from the config file" do
        it "returns its value" do
          expect(SemaphoreConfig.secret_available_only_from_config_file).to eq("test")
        end
      end

      context "when the config isn't aviable from the config file" do
        before do
          expect(ENV.keys).not_to include("SUPER_DB_PASSWORD")
        end

        it "returns nil" do
          expect(SemaphoreConfig.super_db_password).to be_nil
        end
      end
    end
  end

end
