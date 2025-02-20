defmodule RepositoryHub.Model.RepositoryQuery.Test do
  use ExUnit.Case, async: true

  alias RepositoryHub.Repo
  alias RepositoryHub.Model.RepositoryQuery

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  # Insert

  test "insert new repository with valid params" do
    params = %{integration_type: "github_app", url: "foo", project_id: UUID.uuid4()}

    assert {:ok, repository} = RepositoryQuery.insert(params)
    assert params.project_id == repository.project_id
    assert params.integration_type == repository.integration_type
  end

  test "inserting new repository fails when required param is not given" do
    params = %{integration_type: "github_app", project_id: UUID.uuid4()}

    ~w(integration_type project_id)a
    |> Enum.map(fn field ->
      params = Map.delete(params, field)
      assert {:error, _} = RepositoryQuery.insert(params)
    end)
  end

  # Get

  test "get existing repository by id" do
    params = %{integration_type: "github_app", url: "foo", project_id: UUID.uuid4()}

    assert {:ok, repo_1} = RepositoryQuery.insert(params)

    assert {:ok, repo_1} == RepositoryQuery.get_by_id(repo_1.id)
  end

  test "get repository by id returns proper error when repository is not found" do
    id = UUID.uuid4()

    assert {:error, msg} = RepositoryQuery.get_by_id(id)
    assert msg == "Repository not found."
  end
end
