defmodule BranchHub.Server do
  require Logger

  alias InternalApi.Branch.{
    Branch,
    DescribeResponse,
    ListResponse,
    FindOrCreateResponse
  }

  alias InternalApi.ResponseStatus
  alias InternalApi.ResponseStatus.Code, as: ResponseCode
  alias BranchHub.Model.BranchesQueries
  alias Util.{Metrics, ToTuple}

  use GRPC.Server, service: InternalApi.Branch.BranchService.Service
  use Sentry.Grpc, service: InternalApi.Branch.BranchService.Service

  def describe(req, _) do
    Metrics.benchmark("Branch.describe", fn ->
      with {:ok, branch_id} <- non_empty_value_or_default(req, :branch_id, :skip),
           {:ok, branch_name} <- non_empty_value_or_default(req, :branch_name, :skip),
           {:ok, project_id} <- non_empty_value_or_default(req, :project_id, :skip),
           true <-
             either_branch_or_project_id_and_branch_name_present(
               branch_id,
               project_id,
               branch_name
             ),
           true <- valid_uuid?(branch_id, "Branch with id: '#{branch_id}' not found."),
           true <-
             valid_uuid?(project_id, "Branch for Project with id: '#{project_id}' not found."),
           {:ok, branch} <- fetch_branch(branch_id, project_id, branch_name) do
        DescribeResponse.new(
          status: ok_status(),
          branch: serialize(branch),
          branch_name: branch.name,
          branch_id: branch.id,
          project_id: branch.project_id,
          tag_name: map_tag_name(branch.name),
          pr_number: convert_to_string(branch.pull_request_number),
          pr_name: branch.pull_request_name || "",
          type: map_ref_type(branch.ref_type),
          archived_at: map_timestamp(branch.archived_at),
          display_name: branch.display_name || ""
        )
      else
        e = {:error, _message} -> %{status: error_status(e)} |> DescribeResponse.new()
      end
    end)
  end

  def list(req, _) do
    Metrics.benchmark("Branch.list", fn ->
      with {:ok, project_id} <- non_empty_value_or_default(req, :project_id, :skip),
           true <- valid_uuid?(project_id, "Invalid value of field project_id: '#{project_id}'."),
           {:ok, page} <- non_empty_value_or_default(req, :page, 1),
           {:ok, page_size} <- non_empty_value_or_default(req, :page_size, 100),
           {:ok, with_archived} <- non_empty_value_or_default(req, :with_archived, :skip),
           {:ok, types} <- non_empty_value_or_default(req, :types, :skip),
           types <- parse_types(types),
           {:ok, name_contains} <- non_empty_value_or_default(req, :name_contains, :skip),
           query_params <- %{
             project_id: project_id,
             with_archived: with_archived,
             types: types,
             name_contains: name_contains
           },
           {:ok, result_page} <- BranchesQueries.list(query_params, page, page_size) do
        ListResponse.new(
          status: ok_status(),
          branches: serialize(result_page.entries),
          page_number: result_page.page_number,
          page_size: result_page.page_size,
          total_entries: result_page.total_entries,
          total_pages: result_page.total_pages
        )
      else
        e = {:error, _message} -> %{status: error_status(e)} |> ListResponse.new()
      end
    end)
  end

  def find_or_create(req, _) do
    Metrics.benchmark("Branch.find_or_create", fn ->
      with {:ok, project_id} <- non_empty_value_or_default(req, :project_id, :skip),
           true <- valid_uuid?(project_id, "Invalid value of field project_id: '#{project_id}'."),
           {:ok, repository_id} <- non_empty_value_or_default(req, :repository_id, :skip),
           true <-
             valid_uuid?(
               repository_id,
               "Invalid value of field repository_id: '#{repository_id}'."
             ),
           {:ok, name} <- non_empty_value_or_default(req, :name, :skip),
           {:ok, display_name} <- non_empty_value_or_default(req, :display_name, :skip),
           ref_type <- parse_types(req.ref_type),
           {:ok, pr_name} <- non_empty_value_or_default(req, :pr_name, :skip),
           {:ok, pr_number} <- non_empty_value_or_default(req, :pr_number, :skip),
           insert_params = %{
             project_id: project_id,
             repository_id: repository_id,
             name: name,
             display_name: display_name,
             ref_type: ref_type,
             pr_name: pr_name,
             pr_number: pr_number
           },
           {:ok, branch} <- BranchesQueries.get_or_insert(insert_params) do
        FindOrCreateResponse.new(
          status: ok_status(),
          branch: serialize(branch)
        )
      else
        e = {:error, _message} -> %{status: error_status(e)} |> FindOrCreateResponse.new()
      end
    end)
  end

  def archive(req, _) do
    Metrics.benchmark("Branch.archive", fn ->
      with {:ok, branch_id} <- non_empty_value_or_default(req, :branch_id, :skip),
           branch_id when branch_id != :skip <- branch_id,
           true <- valid_uuid?(branch_id, "Branch with id: '#{branch_id}' not found."),
           {:ok, _branch} <- BranchesQueries.archive(branch_id) do
        InternalApi.Branch.ArchiveResponse.new(status: ok_status())
      else
        :skip ->
          InternalApi.Branch.ArchiveResponse.new(
            status: error_status({:error, "Branch ID is required."})
          )

        e = {:error, _message} ->
          InternalApi.Branch.ArchiveResponse.new(status: error_status(e))
      end
    end)
  end

  def filter(_, _) do
    InternalApi.Branch.FilterResponse.new()
  end

  # Utility

  defp serialize(branches) when is_list(branches) do
    branches |> Enum.map(fn b -> serialize(b) end)
  end

  defp serialize(branch) do
    Branch.new(
      id: branch.id,
      name: branch.name,
      project_id: branch.project_id,
      tag_name: map_tag_name(branch.name),
      pr_number: convert_to_string(branch.pull_request_number),
      pr_name: branch.pull_request_name || "",
      type: map_ref_type(branch.ref_type),
      archived_at: map_timestamp(branch.archived_at),
      display_name: branch.display_name || ""
    )
  end

  defp map_tag_name(branch_name) do
    if String.starts_with?(branch_name, "refs/tags/") do
      String.replace_prefix(branch_name, "refs/tags/", "")
    else
      ""
    end
  end

  defp map_ref_type("pull-request"), do: Branch.Type.value(:PR)
  defp map_ref_type("tag"), do: Branch.Type.value(:TAG)
  defp map_ref_type("branch"), do: Branch.Type.value(:BRANCH)
  defp map_ref_type(_), do: Branch.Type.value(:BRANCH)

  defp parse_types(:skip), do: :skip

  defp parse_types(types) when is_list(types) do
    types |> Enum.map(fn type -> parse_types(type) end)
  end

  defp parse_types(type) when is_number(type), do: parse_types(Branch.Type.key(type))
  defp parse_types(:PR), do: "pull-request"
  defp parse_types(:TAG), do: "tag"
  defp parse_types(:BRANCH), do: "branch"

  defp map_timestamp(nil), do: nil

  defp map_timestamp(seconds) when is_integer(seconds),
    do: Google.Protobuf.Timestamp.new(seconds: seconds)

  defp map_timestamp(datetime), do: DateTime.to_unix(datetime, :second) |> map_timestamp()

  defp fetch_branch(:skip, project_id, branch_name) do
    BranchesQueries.get_by_name(branch_name, project_id)
  end

  defp fetch_branch(branch_id, _, _) do
    BranchesQueries.get_by_id(branch_id)
  end

  defp non_empty_value_or_default(map, key, default) do
    case Map.get(map, key) do
      val when is_integer(val) and val > 0 -> {:ok, val}
      val when is_binary(val) and val != "" -> {:ok, val}
      val when is_list(val) and length(val) > 0 -> {:ok, val}
      val when is_boolean(val) -> {:ok, val}
      _ -> {:ok, default}
    end
  end

  defp either_branch_or_project_id_and_branch_name_present(:skip, :skip, :skip) do
    "Either 'branch_id' or 'project_id' and 'branch_name' parameters are required."
    |> ToTuple.error()
  end

  defp either_branch_or_project_id_and_branch_name_present(:skip, _, :skip) do
    "Either 'branch_id' or 'project_id' and 'branch_name' parameters are required."
    |> ToTuple.error()
  end

  defp either_branch_or_project_id_and_branch_name_present(:skip, :skip, _) do
    "Either 'branch_id' or 'project_id' and 'branch_name' parameters are required."
    |> ToTuple.error()
  end

  defp either_branch_or_project_id_and_branch_name_present(_, _, _), do: true

  defp valid_uuid?(:skip, _), do: true

  defp valid_uuid?(value, error_message) do
    case UUID.info(value) do
      {:ok, _} -> true
      _ -> {:error, {:not_found, error_message}}
    end
  end

  defp ok_status,
    do: ResponseStatus.new(code: ResponseCode.value(:OK), message: "")

  defp error_status({:error, message}),
    do: ResponseStatus.new(code: ResponseCode.value(:BAD_PARAM), message: to_str(message))

  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)

  defp convert_to_string(value) when is_number(value), do: to_string(value)
  defp convert_to_string(value), do: value
end
