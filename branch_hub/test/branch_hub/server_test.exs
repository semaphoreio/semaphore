defmodule BranchHub.Server.Test do
  use ExUnit.Case

  alias BranchHub.Repo
  alias BranchHub.Server

  alias InternalApi.Branch.{
    Branch,
    DescribeRequest,
    ListRequest,
    FindOrCreateRequest
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe ".describe" do
    test "return error state when required params is missing" do
      assert {:ok, branch} = insert_branch()

      assert_describe_branch_status("", branch.name, "", :error)
      assert_describe_branch_status("", "", branch.project_id, :error)
    end

    test "return error state when branch is missing" do
      assert_describe_branch_status("does-not-exist", "", "", :error)
    end

    test "return ok state when params are in place and branch exists" do
      assert {:ok, branch} = insert_branch()

      assert_describe_branch_status(branch.id, "", "", :ok)
      assert_describe_branch_status("", branch.name, branch.project_id, :ok)

      assert_describe_branch_status(branch.id, "foo", "", :ok)
    end

    test "describes branch if it is present" do
      assert {:ok, branch} = insert_branch(ref_type: "branch")

      assert_describe_branch_values(branch, :BRANCH)
    end

    test "describes tag if it is present" do
      assert {:ok, branch} = insert_branch(ref_type: "tag")

      assert_describe_branch_values(branch, :TAG)
    end

    test "describes pr if it is present" do
      assert {:ok, branch} = insert_branch(ref_type: "pull-request")

      assert_describe_branch_values(branch, :PR)
    end
  end

  defp assert_describe_branch_status(branch_id, branch_name, project_id, expected_status) do
    %{branch_id: branch_id, branch_name: branch_name, project_id: project_id}
    |> DescribeRequest.new()
    |> describe_branch(expected_status)
  end

  defp assert_describe_branch_values(branch, type) do
    response =
      %{branch_id: branch.id}
      |> DescribeRequest.new()
      |> describe_branch(:ok)

    assert response.id == branch.id
    assert response.name == branch.name
    assert response.display_name == branch.display_name
    assert response.project_id == branch.project_id
    assert response.type == Branch.Type.value(type)
  end

  defp describe_branch(request, expected_status) when is_map(request) do
    response = Server.describe(request, nil)

    assert %{
             branch: branch,
             status: %{code: status_code}
           } = response

    assert code(expected_status) == status_code
    branch
  end

  describe ".list" do
    test "return error when project_id has invalid value" do
      params = %{project_id: "asd"}
      assert_list_status(params, :error)
    end

    test "return ok when project_id is valid" do
      params = %{project_id: UUID.uuid4()}
      assert_list_status(params, :ok)
    end

    test "return proper branches based on terms" do
      project_id = UUID.uuid4()

      assert {:ok, branch_1} =
               insert_branch(project_id: project_id, ref_type: "branch", display_name: "master")

      assert {:ok, branch_2} =
               insert_branch(
                 project_id: project_id,
                 ref_type: "branch",
                 display_name: "master2",
                 archived_at: DateTime.utc_now()
               )

      assert {:ok, branch_3} =
               insert_branch(project_id: project_id, ref_type: "tag", display_name: "mad")

      assert {:ok, branch_4} =
               insert_branch(
                 project_id: project_id,
                 ref_type: "pull-request",
                 display_name: "martens"
               )

      assert {:ok, branch_5} =
               insert_branch(
                 project_id: project_id,
                 ref_type: "pull-request",
                 display_name: "mas"
               )

      assert {:ok, branch_6} = insert_branch(ref_type: "branch", display_name: "master")

      params = %{project_id: project_id}
      assert_list_values(params, [branch_1, branch_3, branch_4, branch_5])

      params = %{project_id: project_id, with_archived: true}
      assert_list_values(params, [branch_1, branch_2, branch_3, branch_4, branch_5])

      params = %{project_id: project_id, with_archived: true, page: 2, page_size: 2}
      assert_list_values(params, [branch_3, branch_4])

      params = %{project_id: branch_6.project_id}
      assert_list_values(params, [branch_6])

      params = %{
        project_id: project_id,
        types: [Branch.Type.value(:BRANCH), Branch.Type.value(:PR)]
      }

      assert_list_values(params, [branch_1, branch_4, branch_5])

      params = %{
        project_id: project_id,
        types: [Branch.Type.value(:BRANCH), Branch.Type.value(:PR)],
        name_contains: "mas"
      }

      assert_list_values(params, [branch_1, branch_5])
    end
  end

  defp assert_list_status(params, expected_status) do
    params
    |> ListRequest.new()
    |> list_branches(expected_status)
  end

  defp assert_list_values(params, expected_results) do
    results =
      params
      |> ListRequest.new()
      |> list_branches(:ok)

    assert Enum.map(results, & &1.id) |> Enum.sort() ==
             Enum.map(expected_results, & &1.id) |> Enum.sort()
  end

  defp list_branches(request, expected_status) do
    response = Server.list(request, nil)

    assert %{
             branches: branches,
             status: %{code: status_code}
           } = response

    assert code(expected_status) == status_code
    branches
  end

  describe ".find_or_create" do
    test "return error when project_id has invalid value" do
      params = %{project_id: "asd"}
      assert_create_status(params, :error)
    end

    test "return error when repository_id has invalid value" do
      params = %{project_id: UUID.uuid4(), repository_id: "asd"}
      assert_create_status(params, :error)
    end

    test "return ok when params are valid" do
      params = %{
        project_id: UUID.uuid4(),
        repository_id: UUID.uuid4(),
        name: "branch",
        display_name: "branch"
      }

      assert_create_status(params, :ok)
    end
  end

  defp assert_create_status(params, expected_status) do
    params
    |> FindOrCreateRequest.new()
    |> find_or_create_branch(expected_status)
  end

  defp find_or_create_branch(request, expected_status) when is_map(request) do
    response = Server.find_or_create(request, nil)

    assert %{
             branch: branch,
             status: %{code: status_code}
           } = response

    assert code(expected_status) == status_code
    branch
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

  defp code(:ok), do: 0
  defp code(:error), do: 1
end
