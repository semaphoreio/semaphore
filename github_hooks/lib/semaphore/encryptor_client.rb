module Semaphore
  class EncryptorClient

    def self.encrypt(data, data_associated_id)
      client = InternalApi::Encryptor::Encryptor::Stub.new(App.encryptor_url, :this_channel_is_insecure)
      req = InternalApi::Encryptor::EncryptRequest.new(raw: data, associated_data: data_associated_id)

      begin
        response = client.encrypt(req)
        response.cypher
      rescue StandardError => e
        Logman.error "Error while encrypting a secret with req #{req.inspect}. Error: #{e.inspect}"
        nil
      end
    end

    def self.decrypt(encrypted_data, data_associated_id)
      client = InternalApi::Encryptor::Encryptor::Stub.new(App.encryptor_url, :this_channel_is_insecure)
      req = InternalApi::Encryptor::DecryptRequest.new(cypher: encrypted_data, associated_data: data_associated_id)

      begin
        response = client.decrypt(req)
        response.raw
      rescue StandardError => e
        Logman.error "Error while decrypting a secret with req #{req.inspect}. Error: #{e.inspect}"
        nil
      end
    end
  end
end
