defmodule RepositoryHub.Server.VerifyWebhookSignatureActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.VerifyWebhookSignatureAction
  alias RepositoryHub.InternalApiFactory
  alias RepositoryHub.RepositoryModelFactory

  setup do
    {:ok, repository} = RepositoryModelFactory.create_repository()

    %{repository: repository}
  end

  describe "Universal VerifyWebhookSignatureAction" do
    test "passes verification for valid signature and payload", %{repository: repository} do
      payload = "Hello, World!"
      signature = "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"

      request =
        InternalApiFactory.verify_webhook_signature_request(
          repository_id: repository.id,
          payload: payload,
          signature: signature
        )

      assert {:ok, response} = VerifyWebhookSignatureAction.execute(Adapters.pick!(request), request)
      assert response == InternalApiFactory.verify_webhook_signature_response(valid: true)
    end

    test "fails verification if signature is invalid", %{repository: repository} do
      payload = "Hello, World!"
      signature = "sha256=invalid"

      request =
        InternalApiFactory.verify_webhook_signature_request(
          repository_id: repository.id,
          payload: payload,
          signature: signature
        )

      assert {:ok, response} = VerifyWebhookSignatureAction.execute(Adapters.pick!(request), request)
      assert response == InternalApiFactory.verify_webhook_signature_response(valid: false)
    end

    test "fails verification if signature format is invalid", %{repository: repository} do
      payload = "Hello, World!"
      signature = "757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"

      request =
        InternalApiFactory.verify_webhook_signature_request(
          repository_id: repository.id,
          payload: payload,
          signature: signature
        )

      assert {:ok, response} = VerifyWebhookSignatureAction.execute(Adapters.pick!(request), request)
      assert response == InternalApiFactory.verify_webhook_signature_response(valid: false)
    end

    test "fails verification if payload does not match signature", %{repository: repository} do
      payload = "hello, world!"
      signature = "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"

      request =
        InternalApiFactory.verify_webhook_signature_request(
          repository_id: repository.id,
          payload: payload,
          signature: signature
        )

      assert {:ok, response} = VerifyWebhookSignatureAction.execute(Adapters.pick!(request), request)
      assert response == InternalApiFactory.verify_webhook_signature_response(valid: false)
    end

    test "returns an error when repository does not exist" do
      payload = "does not matter"
      signature = "does not matter"

      request =
        InternalApiFactory.verify_webhook_signature_request(
          repository_id: Ecto.UUID.generate(),
          payload: payload,
          signature: signature
        )

      assert {:error, error} = VerifyWebhookSignatureAction.execute(Adapters.pick!(request), request)
      assert error == "Repository not found."
    end
  end
end
