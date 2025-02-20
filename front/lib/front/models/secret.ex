defmodule Front.Models.Secret do
  use Ecto.Schema
  require Logger

  alias Front.Models.ConfigFile
  alias Front.Models.EnvironmentVariable
  alias Front.Models.SecretUpdater

  alias InternalApi.Secrethub.{
    CreateRequest,
    DescribeRequest,
    DestroyRequest,
    ListKeysetRequest,
    UpdateRequest
  }

  alias InternalApi.Secrethub.Secret, as: ApiSecret
  alias InternalApi.Secrethub.Secret.{Data, EnvVar, File, Metadata}
  alias InternalApi.Secrethub.SecretService.Stub

  alias Util.Proto

  embedded_schema do
    field(:name, :string)
    field(:description, :string)
    field(:updated_at, :string)
    field(:env_vars, {:array, :map})
    field(:files, {:array, :map})
    field(:level, :integer)

    embeds_one :org_config, OrgConfig do
      field(:projects_access, :integer)
      field(:project_ids, {:array, :string})
      field(:debug_access, :integer)
      field(:attach_access, :integer)
    end

    embeds_one :project_config, ProjectConfig do
      field(:project_id, :string)
    end
  end

  @required_fields [:name]

  def find(id_or_name, user_id, org_id, level_params \\ []) do
    Watchman.benchmark("fetch_secret.duration", fn ->
      default_level_params = [secret_level: :ORGANIZATION, project_id: ""]

      params = Keyword.merge(default_level_params, level_params)

      req =
        req_id_or_name(id_or_name, params, user_id, org_id)
        |> Proto.deep_new!(DescribeRequest)

      with :ok <- is_authorized?(org_id, user_id, :describe, params),
           {:ok, api_response} <- Stub.describe(channel(), req),
           {:ok, secret} <- from_api(api_response) do
        {:ok, construct(secret)}
      else
        {:error_meta, error} ->
          {:error, parse_error_from_metadata(:create, error)}

        {:error, error} ->
          Logger.error("Fetching a secret: #{id_or_name} failed with: #{inspect(error)}")

          error_response(error)

        :permission_denied ->
          {:error, :permission_denied}
      end
    end)
  end

  def list(user_id, org_id, project_id \\ "", level \\ :ORGANIZATION, ignore_contents \\ false) do
    Watchman.benchmark("list_secrets.duration", fn ->
      if :ok ==
           is_authorized?(org_id, user_id, :list, project_id: project_id, secret_level: level) do
        append_secrets_to_list([], %{
          metadata: %{org_id: org_id, user_id: user_id},
          project_id: project_id,
          secret_level: level,
          ignore_contents: ignore_contents
        })
      else
        []
      end
    end)
  end

  def create(name, params, config, level, user_id, org_id) do
    Watchman.benchmark("create_secret.duration", fn ->
      alias Front.Form.RequiredParams, as: RP

      changeset =
        params
        |> Map.put(:name, name)
        |> RP.create_changeset(@required_fields, %__MODULE__{})

      with :ok <-
             is_authorized?(org_id, user_id, :create,
               project_id: Map.get(config || %{}, :project_id, ""),
               secret_level: level
             ),
           true <- changeset.valid?,
           req <-
             CreateRequest.new(
               secret:
                 ApiSecret.new(
                   metadata:
                     Metadata.new(
                       name: name,
                       description: Map.get(params, :description, ""),
                       created_by: user_id,
                       updated_by: user_id,
                       org_id: org_id,
                       level: ApiSecret.SecretLevel.value(level)
                     ),
                   data:
                     Data.new(
                       env_vars: env_vars_from_params(params),
                       files: files_from_params(params)
                     ),
                   org_config: org_config_from_struct(config),
                   project_config: project_config_from_struct(config)
                 ),
               metadata: metadata(user_id, org_id)
             ),
           {:ok, api_response} <-
             Stub.create(channel(), req),
           {:ok, secret} <- from_api(api_response) do
        {:ok, construct(secret)}
      else
        false ->
          {:error, changeset}

        {:error_meta, error = %{code: _, message: _}} ->
          {:error, parse_error_from_metadata(:create, error)}

        {:error, error} ->
          Logger.error("Creating a secret: #{name} failed with: #{inspect(error)}")

          {:error, parse_error_message(:create, error, user_id, org_id)}

        :permission_denied ->
          {:error, :permission_denied}
      end
    end)
  end

  defp from_api(%{metadata: metadata, secret: secret}) do
    if metadata.status.code == :OK or metadata.status.code == 0 do
      {:ok, secret}
    else
      {:error_meta, metadata.status}
    end
  end

  defp from_api(%{metadata: metadata, secrets: secrets}) do
    if metadata.status.code == :OK or metadata.status.code == 0 do
      {:ok, secrets}
    else
      {:error_meta, metadata.status}
    end
  end

  defp from_api(%{metadata: metadata}) do
    if metadata.status.code == :OK or metadata.status.code == 0 do
      {:ok, nil}
    else
      {:error_meta, metadata.status}
    end
  end

  defp parse_error_from_metadata(_, error) do
    Watchman.increment("secret.create.failed")

    cond do
      error.code in [:NOT_FOUND, 2] ->
        :not_found

      error.code in [:FAILED_PRECONDITION, 3] ->
        if error.message =~ "name" do
          %{errors: %{name: error.message}}
        else
          %{errors: %{other: error.message}}
        end

      true ->
        %{errors: %{other: error.message}}
    end
  end

  defp parse_error_message(:create, error, user_id, org_id) do
    status = error.status

    cond do
      status == GRPC.Status.not_found() ->
        :not_found

      status == GRPC.Status.permission_denied() ->
        :permission_denied

      error.message =~ "name" ->
        %{errors: %{name: error.message}}

      true ->
        Watchman.increment("secret.create.failed")

        Logger.error(
          "Creating a secret failed: with an unprocessed error in form: #{inspect(error.message)}; user: #{user_id}; org: #{org_id}"
        )

        %{errors: %{other: error.message}}
    end
  end

  defp parse_error_message(:update, error) do
    status = error.status

    cond do
      status == GRPC.Status.invalid_argument() -> "Failed: #{error.message}"
      status == GRPC.Status.not_found() -> :not_found
      status == GRPC.Status.permission_denied() -> :permission_denied
      true -> "Secret operation failed."
    end
  end

  def update(
        id,
        name,
        description,
        env_vars_params,
        files_params,
        user_id,
        org_id,
        level_params \\ []
      ) do
    Watchman.benchmark("update_secret.duration", fn ->
      with {:ok, secret} <- find(id, user_id, org_id, level_params),
           updated_secret <-
             SecretUpdater.consolidate(
               secret,
               env_vars_params,
               files_params
             ),
           api_secret <-
             ApiSecret.new(
               metadata:
                 Metadata.new(
                   name: name,
                   description: description || "",
                   id: id,
                   updated_by: user_id,
                   org_id: org_id,
                   level: secret.level
                 ),
               data:
                 Data.new(
                   env_vars:
                     Enum.map(updated_secret.env_vars, fn var ->
                       EnvVar.new(name: var.name, value: var.value)
                     end),
                   files:
                     Enum.map(updated_secret.files, fn file ->
                       File.new(path: file.path, content: file.content)
                     end)
                 ),
               org_config: org_config_from_struct(level_params[:org_config]),
               project_config: project_config_from_struct(level_params[:project_config])
             ),
           req <-
             UpdateRequest.new(
               metadata: metadata(user_id, org_id),
               secret: api_secret
             ),
           :ok <-
             is_authorized?(org_id, user_id, :update,
               secret_level: ApiSecret.SecretLevel.key(secret.level),
               project_id: secret.project_config.project_id
             ),
           {:ok, res} <- Stub.update(channel(), req),
           {:ok, secret} <- from_api(res) do
        {:ok, construct(secret)}
      else
        {:error, error} when is_atom(error) ->
          {:error, error}

        {:error, error} ->
          Logger.error("Updating a secret: #{name} failed with: #{inspect(error)}")

          {:error, parse_error_message(:update, error)}

        {:error_meta, error = %{code: _, message: _}} ->
          {:error, parse_error_from_metadata(:create, error)}

        :permission_denied ->
          {:error, :permission_denied}
      end
    end)
  end

  defp env_vars_from_params(params) do
    params[:env_vars]
    |> Enum.map(fn var ->
      EnvVar.new(name: var["name"], value: var["value"])
    end)
  end

  defp files_from_params(params) do
    params[:files]
    |> Enum.map(fn var ->
      File.new(path: var["path"], content: var["content"])
    end)
  end

  defp org_config_from_struct(nil), do: nil

  defp org_config_from_struct(params) do
    params
    |> Util.Proto.deep_new!(ApiSecret.OrgConfig)
  end

  defp project_config_from_struct(nil), do: nil

  defp project_config_from_struct(params) do
    params
    |> Util.Proto.deep_new!(ApiSecret.ProjectConfig)
  end

  def destroy(id, user_id, org_id, level_params \\ []) do
    Watchman.benchmark("delete_secret.duration", fn ->
      default_level_params = [secret_level: :ORGANIZATION, project_id: ""]
      params = Keyword.merge(default_level_params, level_params)

      req =
        req_id_or_name(id, params, user_id, org_id)
        |> Proto.deep_new!(DestroyRequest)

      with :ok <- is_authorized?(org_id, user_id, :destroy, params),
           {:ok, resp} <- Stub.destroy(channel(), req),
           {:ok, _} <- from_api(resp) do
        {:ok, nil}
      else
        {:error, error} ->
          Logger.error("Deleting a secret: #{id} failed with: #{inspect(error)}")

          error_response(error)

        {:error_meta, error} ->
          {:error, parse_error_from_metadata(:create, error)}

        :permission_denied ->
          {:error, :permission_denied}
      end
    end)
  end

  defp error_response(%{metadata: %{status: error}}) do
    if error.code == :NOT_FOUND do
      {:error, :not_found}
    else
      {:error, :other}
    end
  end

  defp error_response(error = %{status: _, message: _}) do
    if error.status == GRPC.Status.not_found() do
      {:error, :not_found}
    else
      {:error, :other}
    end
  end

  defp append_secrets_to_list(secrets, params, page \\ "") do
    {new_secrets, next_page} = list_secrets(params, page)

    if next_page == "" do
      secrets ++ new_secrets
    else
      append_secrets_to_list(secrets ++ new_secrets, params, next_page)
    end
  end

  def list_secrets(params, page_token) do
    req =
      params
      |> Map.put(:page_token, page_token)
      |> Map.put(:page_size, 100)
      |> Proto.deep_new!(ListKeysetRequest)

    response = Stub.list_keyset(channel(), req)

    with {:ok, res} <- response,
         {:ok, secrets} <- from_api(res) do
      {construct_list(secrets) |> serialize_for_frontend(), res.next_page_token}
    else
      _ -> {[], ""}
    end
  end

  def serialize_for_frontend(secrets) when is_list(secrets) do
    secrets |> Enum.map(&serialize_for_frontend(&1))
  end

  def serialize_for_frontend(secret) do
    %{
      id: secret.id,
      name: secret.name,
      updated_at: secret.updated_at,
      description: secret.description,
      env_vars:
        Enum.map(secret.env_vars, fn env ->
          EnvironmentVariable.serialize_for_frontend(env)
        end),
      files:
        Enum.map(secret.files, fn file ->
          ConfigFile.serialize_for_frontend(file)
        end),
      org_config: %{
        projects_access: secret.org_config.projects_access,
        project_ids: secret.org_config.project_ids,
        debug_access: secret.org_config.debug_access,
        attach_access: secret.org_config.attach_access
      }
    }
  end

  defp construct_list(raw_secrets) do
    raw_secrets
    |> Enum.map(&construct(&1))
  end

  defp construct(org_config = %ApiSecret.OrgConfig{}) do
    __MODULE__.OrgConfig
    |> struct(Proto.to_map!(org_config))
  end

  defp construct(raw_secret) do
    %__MODULE__{
      id: raw_secret.metadata.id,
      name: raw_secret.metadata.name,
      description: raw_secret.metadata.description,
      updated_at:
        Front.Utils.decorate_relative(
          raw_secret.metadata.updated_at && raw_secret.metadata.updated_at.seconds
        ),
      env_vars: EnvironmentVariable.construct_list(raw_secret.data),
      files: ConfigFile.construct_list(raw_secret.data),
      level: raw_secret.metadata.level,
      project_config: %__MODULE__.ProjectConfig{
        project_id: raw_secret.project_config && raw_secret.project_config.project_id
      },
      org_config: construct(raw_secret.org_config || ApiSecret.OrgConfig.new())
    }
  end

  defp channel do
    endpoint = Application.fetch_env!(:front, :secrets_api_grpc_endpoint)

    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} -> channel
      # raise error ?
      _ -> nil
    end
  end

  defp req_id_or_name(id_or_name, level_params, user_id, org_id) do
    if uuid?(id_or_name) do
      level_params
      |> Enum.into(%{})
      |> Map.put(:metadata, %{user_id: user_id, org_id: org_id})
      |> Map.put(:id, id_or_name)
    else
      level_params
      |> Enum.into(%{})
      |> Map.put(:metadata, %{user_id: user_id, org_id: org_id})
      |> Map.put(:name, id_or_name)
    end
  end

  defp metadata(user_id, org_id) do
    InternalApi.Secrethub.RequestMeta.new(org_id: org_id, user_id: user_id)
  end

  defp uuid?(id_or_name) do
    String.match?(id_or_name, ~r/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
  end

  defp is_authorized?(org_id, user_id, action, level_params) do
    level = if level_params[:secret_level] == :ORGANIZATION, do: "organization", else: "project"
    operation = if action in [:list, :describe], do: "view", else: "manage"
    permission = level <> ".secrets." <> operation
    project_id = level_params[:project_id] || ""

    if project_id == "" and level == "project" do
      :permission_denied
    else
      if Front.RBAC.Permissions.has?(user_id, org_id, project_id, permission),
        do: :ok,
        else: :permission_denied
    end
  end

  def construct_from_form_input(params, org_config, name) do
    ApiSecret.new(
      metadata: Metadata.new(name: name),
      data:
        Data.new(
          env_vars: env_vars_from_params(params),
          files: files_from_params(params)
        ),
      org_config: org_config |> Proto.deep_new!(ApiSecret.OrgConfig)
    )
    |> construct
  end
end
