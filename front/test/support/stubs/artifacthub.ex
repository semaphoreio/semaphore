defmodule Support.Stubs.Artifacthub do
  alias Support.Stubs.{DB, UUID}
  require Logger

  def init do
    DB.add_table(:artifacts, [:scope, :scope_id, :url, :api_model])
    DB.add_table(:artifacts_retention_policies, [:id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(scope_id, params \\ []) do
    path = Keyword.get(params, :path, UUID.gen())
    scope = Keyword.get(params, :scope, "workflows")
    url = Keyword.get(params, :url, "https://localhost:9000/some_file")

    path
    |> build_artifacts_from_path()
    |> Enum.map(fn api_model ->
      insert_once!(api_model, url, scope, scope_id)
    end)
  end

  defp build_artifacts_from_path(path) do
    path
    |> dissect_path()
    |> Enum.with_index()
    |> Enum.map(fn
      {path, 0} ->
        InternalApi.Artifacthub.ListItem.new(%{name: path, is_directory: false})

      {path, _} ->
        InternalApi.Artifacthub.ListItem.new(%{name: path, is_directory: true})
    end)
  end

  defp insert_once!(api_model, url, scope, scope_id) do
    item = %{
      scope: scope,
      scope_id: scope_id,
      api_model: api_model,
      url: nil
    }

    item =
      api_model
      |> case do
        %{is_directory: false} -> %{item | url: url}
        _ -> item
      end

    DB.filter(:artifacts, item)
    |> case do
      results when results == [] ->
        DB.insert(:artifacts, item)

      [result] ->
        result
    end
  end

  defp dissect_path(path) do
    path
    |> Path.split()
    |> Enum.reduce([], fn
      path_part, [last_path_part | _] = paths ->
        [Path.join(last_path_part, path_part) | paths]

      path_part, [] ->
        [path_part]
    end)
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(ArtifacthubMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(ArtifacthubMock, :list_path, &__MODULE__.list_path/2)
      GrpcMock.stub(ArtifacthubMock, :delete_path, &__MODULE__.delete_path/2)
      GrpcMock.stub(ArtifacthubMock, :get_signed_url, &__MODULE__.get_signed_url/2)

      GrpcMock.stub(
        ArtifacthubMock,
        :update_retention_policy,
        &__MODULE__.update_retention_policy/2
      )
    end

    def describe(req, _) do
      case DB.find_by(:artifacts_retention_policies, :id, req.artifact_id) do
        nil ->
          retention_policy =
            InternalApi.Artifacthub.RetentionPolicy.new(
              project_level_retention_policies: [],
              workflow_level_retention_policies: [],
              job_level_retention_policies: []
            )

          InternalApi.Artifacthub.DescribeResponse.new(retention_policy: retention_policy)

        entry ->
          InternalApi.Artifacthub.DescribeResponse.new(retention_policy: entry.api_model)
      end
    end

    def list_path(req, _) do
      alias InternalApi.Artifacthub, as: Api

      {base_paths, file_path} = split_path(req.path)

      items =
        base_paths
        |> Enum.take(3)
        |> case do
          ["artifacts", scope, scope_id] ->
            DB.filter(:artifacts, scope: scope, scope_id: scope_id)
            |> DB.extract(:api_model)
            |> Enum.filter(fn artifact ->
              file_path
              |> case do
                file_path when file_path == [] ->
                  path_length = Path.split(artifact.name) |> length()
                  path_length == 1

                file_path ->
                  file = Path.join(file_path)

                  length((artifact.name |> Path.split()) -- file_path) == 1 and
                    String.starts_with?(artifact.name, file <> "/")
              end
            end)
            |> Enum.uniq()
        end

      Api.ListPathResponse.new(items: items)
    end

    def get_signed_url(req, _) do
      {_base_paths, file_path} = split_path(req.path)

      if Path.join(file_path) == "dir/non-existing-file.txt" do
        raise GRPC.RPCError, status: :not_found, message: "Requested file was not found."
      else
        get_signed_url_(req)
      end
    end

    def get_signed_url_(req) do
      alias InternalApi.Artifacthub, as: Api

      {base_paths, file_path} = split_path(req.path)

      api_model =
        InternalApi.Artifacthub.ListItem.new(%{name: Path.join(file_path), is_directory: false})

      url =
        base_paths
        |> Enum.take(3)
        |> case do
          ["artifacts", scope, scope_id] ->
            DB.filter(:artifacts, scope: scope, scope_id: scope_id, api_model: api_model)
            |> DB.extract(:url)
        end
        |> case do
          [] -> "http://localhost:9000/non_existent_file"
          [url] -> url
        end

      Api.GetSignedURLResponse.new(url: url)
    end

    def update_retention_policy(req, _) do
      policy = req.retention_policy

      DB.upsert(:artifacts_retention_policies, %{
        id: req.artifact_id,
        api_model: policy
      })

      InternalApi.Artifacthub.UpdateRetentionPolicyResponse.new(retention_policy: policy)
    end

    def delete_path(_, _) do
      InternalApi.Artifacthub.DeletePathResponse.new()
    end

    defp split_path(path) do
      path
      |> Path.split()
      |> Enum.split(3)
    end
  end
end
