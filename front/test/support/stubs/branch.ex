defmodule Support.Stubs.Branch do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:branches, [:id, :project_id, :name, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(project, params \\ []) do
    alias InternalApi.Branch.Branch

    defaults = [
      id: UUID.gen(),
      project_id: project.id,
      name: "master",
      display_name: "master"
    ]

    api_model = defaults |> Keyword.merge(params) |> Branch.new()

    DB.insert(:branches, %{
      id: api_model.id,
      project_id: api_model.project_id,
      name: api_model.name,
      api_model: api_model
    })
  end

  defmodule Grpc do
    alias Support.Stubs.DB

    def init do
      GrpcMock.stub(BranchMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(BranchMock, :list, &__MODULE__.list/2)
    end

    def describe(req, _) do
      case DB.all(:branches) |> filter(req) do
        [] ->
          InternalApi.Branch.DescribeResponse.new(
            status: status(:BAD_PARAM, "Branch with id #{req.branch_id} not found")
          )

        [branch | _] ->
          InternalApi.Branch.DescribeResponse.new(
            status: status(:OK),
            branch_id: branch.id,
            branch_name: branch.name,
            project_id: branch.project_id,
            display_name: branch.api_model.display_name,
            type: branch.api_model.type
          )
      end
    end

    def list(req, _) do
      branches = DB.all(:branches) |> filter(req) |> map_list()

      InternalApi.Branch.ListResponse.new(
        status: status(:OK),
        branches: branches,
        page_number: 1,
        page_size: Enum.count(branches),
        total_entries: Enum.count(branches),
        total_pages: 1
      )
    end

    def status(code, message \\ "") do
      InternalApi.ResponseStatus.new(
        code: InternalApi.ResponseStatus.Code.value(code),
        message: message
      )
    end

    defp map_list(branches) do
      Enum.map(branches, fn branch ->
        InternalApi.Branch.Branch.new(
          id: branch.id,
          name: branch.name,
          project: branch.project_id,
          display_name: branch.name
        )
      end)
    end

    defp filter(branches, params) do
      branches
      |> filter_by_project_id(params)
      |> filter_by_branch_id(params)
      |> filter_by_branch_in_project(params)
      |> filter_by_name_contains(params)
      |> filter_by_archived(params)
      |> filter_by_types(params)
    end

    defp filter_by_project_id(branches, %{project_id: project_id})
         when is_binary(project_id) and project_id != "" do
      Enum.filter(branches, fn b -> b.project_id == project_id end)
    end

    defp filter_by_project_id(branches, _), do: branches

    defp filter_by_branch_id(branches, %{branch_id: branch_id})
         when is_binary(branch_id) and branch_id != "" do
      Enum.filter(branches, fn b -> b.id == branch_id end)
    end

    defp filter_by_branch_id(branches, _), do: branches

    defp filter_by_branch_in_project(branches, %{project_id: project_id, branch_name: name})
         when is_binary(project_id) and project_id != "" and is_binary(name) do
      Enum.filter(branches, fn b -> b.project_id == project_id && b.name == name end)
    end

    defp filter_by_branch_in_project(branches, _), do: branches

    defp filter_by_name_contains(branches, %{name_contains: name})
         when is_binary(name) do
      Enum.filter(branches, fn b -> String.contains?(b.name, name) end)
    end

    defp filter_by_name_contains(branches, _), do: branches

    defp filter_by_archived(branches, %{with_archived: false}), do: branches
    defp filter_by_archived(branches, %{with_archived: true}), do: branches
    defp filter_by_archived(branches, _), do: branches

    defp filter_by_types(branches, _), do: branches
  end
end
