defmodule Front.Models.Branch do
  require Logger

  alias Front.Clients

  alias InternalApi.Branch.ListRequest

  defstruct [
    :id,
    :project_id,
    :name,
    :html_url,
    :tag_name,
    :pr_name,
    :pr_number,
    :type,
    :archived_at,
    :display_name
  ]

  def list(params \\ []) do
    Watchman.benchmark("fetch_branches.duration", fn ->
      defaults = [page: 1, page_size: 100]

      {:ok, response} =
        defaults
        |> Keyword.merge(params)
        |> map_type_params()
        |> ListRequest.new()
        |> Clients.Branch.list()

      if response.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
        {construct_list(response.branches), response.total_pages}
      else
        nil
      end
    end)
  end

  defp map_type_params(params) do
    {_, params} =
      Keyword.get_and_update!(params, :types, fn types ->
        new_types =
          (types || [])
          |> Enum.map(fn type -> map_type_param(type) end)
          |> Enum.filter(fn type -> type !== nil end)

        {types, new_types}
      end)

    params
  rescue
    _e in KeyError ->
      params
  end

  defp map_type_param(nil), do: nil

  defp map_type_param(type) do
    type
    |> String.upcase()
    |> String.to_atom()
    |> InternalApi.Branch.Branch.Type.value()
  rescue
    _e in FunctionClauseError ->
      nil
  end

  def list_and_filter_branch_type(project_id) do
    case list(project_id: project_id, page_size: 250) do
      {branches, total_pages} ->
        if total_pages > 1, do: observe_branch_response(total_pages, project_id)

        branches
        |> Enum.filter(fn b -> b.name != "" and b.tag_name == "" and b.pr_name == "" end)
        |> Enum.map(fn b -> b.name end)

      nil ->
        []
    end
  end

  def find(project_id, branch_name) do
    Watchman.benchmark("fetch_branch.duration", fn ->
      req =
        InternalApi.Branch.DescribeRequest.new(
          project_id: project_id,
          branch_name: branch_name
        )

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:front, :branch_api_grpc_endpoint))

      {:ok, response} =
        InternalApi.Branch.BranchService.Stub.describe(channel, req, timeout: 30_000)

      if response.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
        construct(response)
      else
        Logger.error("Branch response #{inspect(response)}")

        nil
      end
    end)
  end

  def find_by_id(branch_id) do
    Watchman.benchmark("fetch_branch_by_id.duration", fn ->
      req = InternalApi.Branch.DescribeRequest.new(branch_id: branch_id)

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:front, :branch_api_grpc_endpoint))

      {:ok, response} =
        InternalApi.Branch.BranchService.Stub.describe(channel, req, timeout: 30_000)

      if response.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
        construct(response)
      else
        # there is no other option than a missing branch
        nil
      end
    end)
  end

  defp construct(raw) do
    %__MODULE__{
      id: raw.branch_id,
      html_url: "/branches/#{raw.branch_id}",
      project_id: raw.project_id,
      name: raw.branch_name,
      tag_name: raw.tag_name,
      pr_number: raw.pr_number,
      pr_name: raw.pr_name,
      type: map_type(raw.type),
      display_name: raw.display_name
    }
  end

  defp construct_list(raw_branches) do
    raw_branches
    |> Enum.map(fn branch ->
      %__MODULE__{
        id: branch.id,
        html_url: "/branches/#{branch.id}",
        project_id: branch.project_id,
        name: branch.name,
        tag_name: branch.tag_name,
        pr_number: branch.pr_number,
        pr_name: branch.pr_name,
        type: map_type(branch.type),
        display_name: branch.display_name
      }
    end)
  end

  defp map_type(type) do
    case InternalApi.Branch.Branch.Type.key(type) do
      :PR -> "pull-request"
      :BRANCH -> "branch"
      :TAG -> "tag"
    end
  end

  defp observe_branch_response(page_count, project_id) do
    Watchman.submit({"external.branch_api.response_page_count", [project_id]}, page_count, :count)
  end
end
