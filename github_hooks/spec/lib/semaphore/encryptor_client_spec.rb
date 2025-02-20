require "spec_helper"

RSpec.describe Semaphore::EncryptorClient do
  describe "encrypt and decrypt" do
    it "can decrypt encrypted data" do
      encrypted_data = described_class.encrypt("test_data", "test_id")
      decrypted_data = described_class.decrypt(encrypted_data, "test_id")

      expect(decrypted_data).to eql("test_data")
    end
  end
end
