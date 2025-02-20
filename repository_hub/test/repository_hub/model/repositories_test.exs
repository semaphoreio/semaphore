defmodule RepositoryHub.Model.RepositoriesTest do
  use ExUnit.Case, async: true

  alias RepositoryHub.RepositoryModelFactory
  alias RepositoryHub.Model.Repositories

  doctest Repositories

  @organization_with_strict_hook_verification "9290123e-6066-41ae-8ae3-321964100dce"

  setup do
    repository = RepositoryModelFactory.build_repository()
    repository_empty_secret = RepositoryModelFactory.build_repository(hook_secret_enc: nil)

    [
      repository: repository,
      repository_empty_secret: repository_empty_secret
    ]
  end

  describe "Repositories" do
    test "#hook_signature_valid? is valid for correct payload and signature", %{repository: repository} do
      assert {:ok, true} ==
               Repositories.hook_signature_valid?(
                 repository,
                 @organization_with_strict_hook_verification,
                 "Hello, World!",
                 "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"
               )
    end

    test "#hook_signature_valid? is invalid when secret is missing", %{repository_empty_secret: repository} do
      assert {:ok, false} ==
               Repositories.hook_signature_valid?(
                 repository,
                 @organization_with_strict_hook_verification,
                 "Hello, World!",
                 "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"
               )
    end

    test "#hook_signature_valid? is invalid for incorrect signature", %{repository: repository} do
      assert {:ok, false} ==
               Repositories.hook_signature_valid?(
                 repository,
                 @organization_with_strict_hook_verification,
                 "Hello, World!",
                 "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e15"
               )
    end

    test "#hook_signature_valid? is invalid for incorrect signature format", %{repository: repository} do
      assert {:ok, false} ==
               Repositories.hook_signature_valid?(
                 repository,
                 @organization_with_strict_hook_verification,
                 "Hello, World!",
                 "757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"
               )
    end

    test "#hook_signature_valid? is invalid for incorrect payload", %{repository: repository} do
      assert {:ok, false} ==
               Repositories.hook_signature_valid?(
                 repository,
                 @organization_with_strict_hook_verification,
                 "Hello, World",
                 "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"
               )
    end

    test "#hook_signature_valid? is always valid if feature is disabled for organization", %{repository: repository} do
      assert {:ok, true} ==
               Repositories.hook_signature_valid?(
                 repository,
                 Ecto.UUID.generate(),
                 "",
                 ""
               )
    end

    test "#generate_hook_secret generates a new hook secret and it's encrypted value", %{repository: repository} do
      {:ok, {hook_secret, hook_secret_enc}} = Repositories.generate_hook_secret(repository)

      decrypted_secret =
        RepositoryHub.Encryptor.decrypt!(RepositoryHub.WebhookSecretEncryptor, hook_secret_enc, repository.id)

      assert hook_secret == decrypted_secret
    end
  end
end
