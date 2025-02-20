defmodule RepositoryHub.Model.DeployKeyQuery.Test do
  use ExUnit.Case, async: true

  alias RepositoryHub.Repo
  alias RepositoryHub.Model.{RepositoryQuery, DeployKeyQuery}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  # Insert

  test "insert new keys with valid params" do
    repository_id = UUID.uuid4()
    project_id = UUID.uuid4()
    private_key = "PRIVATE"

    {:ok, private_key_enc} =
      RepositoryHub.Encryptor.encrypt(RepositoryHub.DeployKeyEncryptor, "PRIVATE", "semaphore-#{project_id}")

    params = %{
      private_key: private_key,
      private_key_enc: private_key_enc,
      public_key: "PUBLIC",
      project_id: project_id,
      repository_id: repository_id,
      remote_id: 1
    }

    assert {:ok, key} = DeployKeyQuery.insert(params)
    assert params.project_id == key.project_id
    assert params.public_key == key.public_key

    assert params.private_key ==
             RepositoryHub.Encryptor.decrypt!(
               RepositoryHub.DeployKeyEncryptor,
               key.private_key_enc,
               "semaphore-#{project_id}"
             )
  end

  test "inserting new key fails when required param is not given" do
    params = %{
      private_key: "PRIVATE",
      public_key: "PUBLIC",
      project_id: UUID.uuid4(),
      repository_id: UUID.uuid4(),
      remote_id: 1
    }

    ~w(private_key public_key project_id)a
    |> Enum.map(fn field ->
      params = Map.delete(params, field)
      assert {:error, _} = DeployKeyQuery.insert(params)
    end)
  end

  # Get

  test "get existing ssh key by repository id" do
    project_id = UUID.uuid4()
    project_params = %{id: project_id |> Ecto.UUID.dump!()}

    repo_params = %{
      integration_type: "github_app",
      project_id: project_id,
      url: "https://github.com/semaphoreci/alles"
    }

    assert {1, _} = Repo.insert_all("projects", [project_params], returning: [:id])
    assert {:ok, repo_1} = RepositoryQuery.insert(repo_params)

    {:ok, private_key_enc} =
      RepositoryHub.Encryptor.encrypt(RepositoryHub.DeployKeyEncryptor, "PRIVATE", "semaphore-#{project_id}")

    key_params = %{
      private_key: "PRIVATE",
      private_key_enc: private_key_enc,
      public_key: "PUBLIC",
      project_id: project_id,
      repository_id: repo_1.id,
      remote_id: 1
    }

    assert {:ok, key_1} = DeployKeyQuery.insert(key_params)

    assert {:ok, key_1} == DeployKeyQuery.get_by_repository_id(repo_1.id)
  end

  test "get key by repository id returns proper error when key is not found" do
    id = UUID.uuid4()

    assert {:error, msg} = DeployKeyQuery.get_by_repository_id(id)
    assert msg == "Deploy key for repository not found."
  end
end
