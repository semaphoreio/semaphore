defmodule BranchHub.Model.BranchesQueries.Test do
  use ExUnit.Case, async: true

  alias BranchHub.Repo
  alias BranchHub.Model.BranchesQueries

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  # Insert

  test "insert new branch with valid params" do
    params = [
      name: "rw/branch",
      display_name: "rw/branch",
      ref_type: "branch",
      project_id: UUID.uuid4()
    ]

    assert {:ok, branch} = insert_branch(params)

    assert params[:project_id] == branch.project_id
    assert params[:ref_type] == branch.ref_type
  end

  test "inserting new branch fails when required param is not given" do
    params = %{
      name: "rw/branch",
      display_name: "rw/branch",
      ref_type: "branch",
      project_id: UUID.uuid4()
    }

    ~w(ref_type project_id)a
    |> Enum.map(fn field ->
      subset = Map.delete(params, field)
      assert {:error, _} = BranchesQueries.insert(subset)
    end)
  end

  # Get or insert

  test "update existing branch" do
    params = [
      name: "rw/branch",
      display_name: "rw/branch",
      ref_type: "branch",
      project_id: UUID.uuid4()
    ]

    assert {:ok, branch_1} = upsert_branch(params)
    :timer.sleep(1000)
    assert {:ok, branch_2} = upsert_branch(params)

    assert branch_1.id == branch_2.id
    assert branch_1.inserted_at == branch_2.inserted_at
    refute branch_1.updated_at == branch_2.updated_at
    refute branch_1.used_at == branch_2.used_at
  end

  test "insert new branch if different name" do
    params = [
      name: "rw/branch",
      display_name: "rw/branch",
      ref_type: "branch",
      project_id: UUID.uuid4()
    ]

    assert {:ok, branch_1} = upsert_branch(params)
    :timer.sleep(1000)
    assert {:ok, branch_2} = upsert_branch(Keyword.merge(params, name: "foo"))

    refute branch_1.id == branch_2.id
    refute branch_1.inserted_at == branch_2.inserted_at
    refute branch_1.updated_at == branch_2.updated_at
    refute branch_1.used_at == branch_2.used_at
  end

  test "insert new branch" do
    params = [
      name: "rw/branch",
      display_name: "rw/branch",
      ref_type: "branch",
      project_id: UUID.uuid4()
    ]

    assert {:ok, branch} = upsert_branch(params)

    assert params[:project_id] == branch.project_id
    assert params[:ref_type] == branch.ref_type
  end

  # Get by id

  test "get existing branch by id" do
    assert {:ok, branch_1} = insert_branch()

    assert {:ok, branch_1} == BranchesQueries.get_by_id(branch_1.id)
  end

  test "get branch by id returns error when branch is not found" do
    id = UUID.uuid4()

    assert {:error, msg} = BranchesQueries.get_by_id(id)
    assert msg == "Branch with id: '#{id}' not found."
  end

  # Get by name

  test "get existing branch by name" do
    assert {:ok, branch_1} = insert_branch()

    assert {:ok, branch_1} == BranchesQueries.get_by_name(branch_1.name, branch_1.project_id)
  end

  test "get branch by name returns error when branch is not found" do
    id = UUID.uuid4()
    assert {:ok, branch_1} = insert_branch()

    assert {:error, msg} = BranchesQueries.get_by_name(branch_1.name, id)
    assert msg == "Branch with name: '#{branch_1.name}' in Project with id: '#{id}' not found."

    assert {:error, msg2} = BranchesQueries.get_by_name("foo", branch_1.project_id)

    assert msg2 ==
             "Branch with name: 'foo' in Project with id: '#{branch_1.project_id}' not found."
  end

  # List

  test "get empty list if there are not branches for criteria" do
    params = %{
      project_id: UUID.uuid4(),
      name_contains: :skip,
      with_archived: false,
      types: :skip
    }

    expected_results = %{entries: [], total_entries: 0, total_pages: 1}

    assert_list_branches(params, expected_results)
  end

  test "filter repo by project_id" do
    assert {:ok, branch_1} = insert_branch()
    assert {:ok, _} = insert_branch(project_id: UUID.uuid4())

    params = %{
      project_id: branch_1.project_id,
      name_contains: :skip,
      with_archived: :skip,
      types: :skip
    }

    expected_results = %{entries: [branch_1], total_entries: 1, total_pages: 1}

    assert_list_branches(params, expected_results)
  end

  test "filter repo by name" do
    project_id = UUID.uuid4()
    assert {:ok, branch_1} = insert_branch(project_id: project_id, display_name: "master")
    assert {:ok, branch_2} = insert_branch(project_id: project_id, display_name: "main")
    assert {:ok, _} = insert_branch(project_id: project_id, display_name: "foo")

    params = %{
      project_id: project_id,
      name_contains: "ma",
      with_archived: :skip,
      types: :skip
    }

    expected_results = %{entries: [branch_1, branch_2], total_entries: 2, total_pages: 1}
    assert_list_branches(params, expected_results)

    params = %{
      project_id: project_id,
      name_contains: "mas",
      with_archived: :skip,
      types: :skip
    }

    expected_results = %{entries: [branch_1], total_entries: 1, total_pages: 1}
    assert_list_branches(params, expected_results)
  end

  test "filter repo by archived" do
    project_id = UUID.uuid4()

    assert {:ok, branch_1} =
             insert_branch(project_id: project_id, archived_at: DateTime.utc_now())

    assert {:ok, branch_2} = insert_branch(project_id: project_id)

    params = %{
      project_id: project_id,
      name_contains: :skip,
      with_archived: true,
      types: :skip
    }

    expected_results = %{entries: [branch_1, branch_2], total_entries: 2, total_pages: 1}
    assert_list_branches(params, expected_results)

    params = %{
      project_id: project_id,
      name_contains: :skip,
      with_archived: false,
      types: :skip
    }

    expected_results = %{entries: [branch_2], total_entries: 1, total_pages: 1}
    assert_list_branches(params, expected_results)
  end

  test "filter repo by types" do
    project_id = UUID.uuid4()
    assert {:ok, branch_1} = insert_branch(project_id: project_id, ref_type: "branch")
    assert {:ok, branch_2} = insert_branch(project_id: project_id, ref_type: "tag")
    assert {:ok, branch_3} = insert_branch(project_id: project_id, ref_type: "pull-request")
    assert {:ok, branch_4} = insert_branch(project_id: project_id, ref_type: "pull-request")

    params = %{
      project_id: project_id,
      name_contains: :skip,
      with_archived: :skip,
      types: ["tag"]
    }

    expected_results = %{entries: [branch_2], total_entries: 1, total_pages: 1}
    assert_list_branches(params, expected_results)

    params = %{
      project_id: project_id,
      name_contains: :skip,
      with_archived: :skip,
      types: ["branch", "pull-request"]
    }

    expected_results = %{
      entries: [branch_1, branch_3, branch_4],
      total_entries: 3,
      total_pages: 1
    }

    assert_list_branches(params, expected_results)
  end

  defp assert_list_branches(params, expected_results, page \\ 1, size \\ 10) do
    assert {:ok, results} = BranchesQueries.list(params, page, size)
    assert Enum.sort(results.entries) == Enum.sort(expected_results.entries)
    assert results.page_number == page
    assert results.page_size == size
    assert results.total_entries == expected_results.total_entries
    assert results.total_pages == expected_results.total_pages
  end

  defp insert_branch(params \\ []) do
    alias BranchHub.Model.BranchesQueries

    defaults = [
      name: UUID.uuid4(),
      display_name: "master",
      ref_type: "branch",
      project_id: "12345678-1234-5678-0000-010101010101"
    ]

    defaults |> Keyword.merge(params) |> Enum.into(%{}) |> BranchesQueries.insert()
  end

  defp upsert_branch(params) do
    alias BranchHub.Model.BranchesQueries

    defaults = [
      name: "master",
      display_name: "master",
      ref_type: "branch",
      project_id: "12345678-1234-5678-0000-010101010101"
    ]

    defaults |> Keyword.merge(params) |> Enum.into(%{}) |> BranchesQueries.get_or_insert()
  end
end
