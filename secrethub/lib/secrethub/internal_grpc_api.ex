defmodule Secrethub.InternalGrpcApi do
  alias InternalApi.Secrethub.{
    CreateResponse,
    DescribeManyResponse,
    DescribeResponse,
    ListResponse,
    ListKeysetResponse,
    DestroyResponse,
    GenerateOpenIDConnectTokenResponse,
    ResponseMeta,
    SecretService,
    UpdateResponse,
    CheckoutResponse,
    CheckoutManyResponse,
    GetJWTConfigResponse,
    UpdateJWTConfigResponse
  }

  alias InternalApi.Secrethub, as: API
  alias Secrethub.{Utils, Repo, OpenIDConnect.JWTConfiguration}

  use GRPC.Server, service: SecretService.Service
  use Sentry.Grpc, service: SecretService.Service

  require Logger

  def list(req, _), do: observe("list", :ORGANIZATION, fn -> list(req) end)

  defp list(req) do
    org_id = req.metadata.org_id
    project_id = req.project_id

    secrets =
      Secrethub.Secret
      |> Secrethub.Secret.in_org(org_id)
      |> Secrethub.Secret.in_project(project_id)
      |> Repo.all()
      |> Enum.map(fn s ->
        case Secrethub.Encryptor.decrypt_secret(s) do
          {:ok, secret} -> secret
          _ -> nil
        end
      end)
      |> Enum.map(fn s -> serialize(s, false) end)

    ListResponse.new(metadata: status_ok(req), secrets: secrets)
  end

  def list_keyset(req, _),
    do: observe("list_keyset", req.secret_level, fn -> list_keyset(req) end)

  defp list_keyset(request = %API.ListKeysetRequest{secret_level: :DEPLOYMENT_TARGET}) do
    Secrethub.DeploymentTargets.Actions.handle_list_keyset(request)
  end

  defp list_keyset(request = %API.ListKeysetRequest{secret_level: :PROJECT}) do
    Secrethub.ProjectSecrets.Actions.handle_list_keyset(request)
  end

  defp list_keyset(req) do
    alias Secrethub.PublicGrpcApi.ListSecrets, as: LS

    org_id = req.metadata.org_id
    project_id = req.project_id

    with {:ok, page_size} <- LS.extract_page_size(req),
         {:ok, secrets, next_page_token} <-
           LS.query(org_id, project_id, page_size, req.order, req.page_token, req.ignore_contents) do
      ListKeysetResponse.new(
        metadata: status_ok(req),
        secrets: Enum.map(secrets, fn s -> serialize(s, req.ignore_contents) end),
        next_page_token: next_page_token
      )
    else
      {:error, :precondition_failed, message} ->
        ListKeysetResponse.new(metadata: status_not_ok(req, :FAILED_PRECONDITION, message))
    end
  end

  def describe(req, _), do: observe("describe", req.secret_level, fn -> describe(req) end)

  defp describe(request = %API.DescribeRequest{secret_level: :DEPLOYMENT_TARGET}) do
    Secrethub.DeploymentTargets.Actions.handle_describe(request)
  end

  defp describe(request = %API.DescribeRequest{secret_level: :PROJECT}) do
    Secrethub.ProjectSecrets.Actions.handle_describe(request)
  end

  defp describe(req) do
    case find_secret(req) do
      {:ok, secret} ->
        DescribeResponse.new(metadata: status_ok(req), secret: serialize(secret, false))

      {:error, :not_found} ->
        DescribeResponse.new(metadata: status_not_ok(req, :NOT_FOUND))
    end
  end

  def describe_many(req, _),
    do: observe("describe_many", req.secret_level, fn -> describe_many(req) end)

  defp describe_many(request = %API.DescribeManyRequest{secret_level: :DEPLOYMENT_TARGET}) do
    Secrethub.DeploymentTargets.Actions.handle_describe_many(request)
  end

  defp describe_many(request = %API.DescribeManyRequest{secret_level: :PROJECT}) do
    Secrethub.ProjectSecrets.Actions.handle_describe_many(request)
  end

  defp describe_many(req) do
    {:ok, entries} = Secrethub.Secret.load(req)

    org_secrets = entries |> Enum.map(fn s -> serialize(s, false) end)
    project_secrets = load_many_project_secrets(req)
    dt_secrets = load_many_dt_secrets(req)
    org_secrets = dt_secrets ++ org_secrets

    all_secrets = merge_checkout_secrets(project_secrets, org_secrets)

    DescribeManyResponse.new(metadata: status_ok(req), secrets: all_secrets)
  end

  def create(req, _), do: observe("create", req.secret.metadata.level, fn -> create(req) end)

  defp create(
         request = %API.CreateRequest{
           secret: %API.Secret{metadata: %API.Secret.Metadata{level: :PROJECT}}
         }
       ) do
    Secrethub.ProjectSecrets.Actions.handle_create(request)
  end

  defp create(req) do
    org_id = req.metadata.org_id
    user_id = req.metadata.user_id
    name = req.secret.metadata.name
    description = req.secret.metadata.description
    content = Utils.to_map_with_string_keys(req.secret)

    default_org_config = InternalApi.Secrethub.Secret.OrgConfig.new()

    permissions =
      case req.secret.org_config do
        nil -> Utils.permissions_from_org_config(default_org_config)
        org_conf -> Utils.permissions_from_org_config(org_conf)
      end

    res =
      Secrethub.Secret.save(
        org_id,
        user_id,
        name,
        description,
        content,
        permissions
      )

    case res do
      {:ok, secret} ->
        CreateResponse.new(metadata: status_ok(req), secret: serialize(secret, false))

      {:error, :failed_precondition, message} ->
        CreateResponse.new(metadata: status_not_ok(req, :FAILED_PRECONDITION, message))
    end
  end

  def update(req, _), do: observe("update", req.secret.metadata.level, fn -> update(req) end)

  defp update(
         request = %API.UpdateRequest{
           secret: %API.Secret{metadata: %API.Secret.Metadata{level: :PROJECT}}
         }
       ) do
    Secrethub.ProjectSecrets.Actions.handle_update(request)
  end

  defp update(req) do
    org_id = req.metadata.org_id
    user_id = req.metadata.user_id
    id = req.secret.metadata.id

    new_name = req.secret.metadata.name
    new_description = req.secret.metadata.description
    new_content = Secrethub.Utils.to_map_with_string_keys(req.secret)

    Logger.info("Update Secrets #{org_id} #{user_id} #{id}")

    with true <- id != "",
         {:ok, secret} <- Secrethub.Secret.find(org_id, id),
         consolidated_org_config <- Utils.consolidate_org_configs(req.secret.org_config, secret),
         {:ok, new_secret} <-
           Secrethub.Secret.update(
             org_id,
             user_id,
             secret,
             Map.merge(
               %{
                 name: new_name,
                 description: new_description,
                 content: new_content
               },
               consolidated_org_config
             )
           ) do
      UpdateResponse.new(metadata: status_ok(req), secret: serialize(new_secret, false))
    else
      {:error, :failed_precondition, message} ->
        UpdateResponse.new(metadata: status_not_ok(req, :FAILED_PRECONDITION, message))

      {:error, :not_found} ->
        UpdateResponse.new(
          metadata: status_not_ok(req, :NOT_FOUND, "Secret #{req.secret.metadata.name} not found")
        )

      false ->
        UpdateResponse.new(
          metadata: status_not_ok(req, :FAILED_PRECONDITION, "secret id not provided")
        )

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  def checkout(req, _),
    do: observe("checkout", :ORGANIZATION, fn -> checkout_dt_project_secret_or_regular(req) end)

  defp checkout_dt_project_secret_or_regular(req) do
    req
    |> checkout_dt_secret()
    |> handle_checkout_result(req)
    |> checkout_project_secret()
    |> handle_checkout_result(req)
    |> checkout()
  end

  defp handle_checkout_result({:ok, secret}, req),
    do: CheckoutResponse.new(metadata: status_ok(req), secret: secret)

  defp handle_checkout_result({:error, :not_found}, req), do: req

  defp checkout_dt_secret(req) do
    alias Secrethub.DeploymentTargets.Store, as: DTStore
    alias Secrethub.DeploymentTargets.Mapper, as: DTMapper

    find_dt_secret_fun =
      cond do
        not String.equivalent?(req.id, "") ->
          fn -> DTStore.find_by_id(req.metadata.org_id, :skip, req.id) end

        not String.equivalent?(req.name, "") ->
          fn -> DTStore.find_by_name(req.metadata.org_id, req.name) end

        true ->
          fn -> {:error, :not_found} end
      end

    if req.checkout_metadata do
      params = Map.from_struct(req.checkout_metadata)

      with {:ok, secret} <- find_dt_secret_fun.(),
           {:ok, secret} <- DTStore.checkout(secret, params) do
        {:ok, DTMapper.encode(secret)}
      end
    else
      CheckoutManyResponse.new(
        metadata: status_not_ok(req, :FAILED_PRECONDITION, "checkout_metadata is required")
      )
    end
  end

  defp checkout_project_secret(resp = %API.CheckoutResponse{}), do: resp

  defp checkout_project_secret(req) do
    alias Secrethub.ProjectSecrets.Store, as: ProjectSecretStore
    alias Secrethub.ProjectSecrets.Mapper, as: ProjectSecretMapper

    find_project_secret_fun =
      cond do
        not String.equivalent?(req.id, "") ->
          fn -> ProjectSecretStore.find_by_id(req.metadata.org_id, req.project_id, req.id) end

        not String.equivalent?(req.name, "") ->
          fn -> ProjectSecretStore.find_by_name(req.metadata.org_id, req.project_id, req.name) end

        true ->
          fn -> {:error, :not_found} end
      end

    if req.checkout_metadata do
      params = Map.from_struct(req.checkout_metadata)

      with {:ok, secret} <- find_project_secret_fun.(),
           {:ok, secret} <- ProjectSecretStore.checkout(secret, params) do
        {:ok, ProjectSecretMapper.encode(secret)}
      end
    else
      CheckoutManyResponse.new(
        metadata: status_not_ok(req, :FAILED_PRECONDITION, "checkout_metadata is required")
      )
    end
  end

  defp checkout(resp = %API.CheckoutResponse{}), do: resp

  defp checkout(req) do
    if req.checkout_metadata do
      usage_data = Map.from_struct(req.checkout_metadata)

      with {:ok, secret} <- find_secret(req),
           {:ok, secret} <- Secrethub.Secret.update_usage(secret, usage_data) do
        CheckoutResponse.new(metadata: status_ok(req), secret: serialize(secret, false))
      else
        {:error, :not_found} ->
          CheckoutResponse.new(metadata: status_not_ok(req, :NOT_FOUND))

        {:error, :failed_precondition, message} ->
          CheckoutResponse.new(metadata: status_not_ok(req, :FAILED_PRECONDITION, message))

        {:error, :unknown, message} ->
          raise GRPC.RPCError, status: :unknown, message: message
      end
    else
      CheckoutManyResponse.new(
        metadata: status_not_ok(req, :FAILED_PRECONDITION, "checkout_metadata is required")
      )
    end
  end

  def checkout_many(req, _),
    do: observe("checkout_many", :ORGANIZATION, fn -> checkout_many(req) end)

  defp checkout_many(req) do
    if req.checkout_metadata do
      usage_data = Map.from_struct(req.checkout_metadata)

      {:ok, entries} = Secrethub.Secret.load(req)

      entries
      |> Enum.each(fn entry ->
        {:ok, _} = Secrethub.Secret.update_usage(entry, usage_data)
      end)

      secrets = entries |> Enum.map(fn s -> serialize(s, false) end)

      dt_secrets = checkout_many_dt_secrets(req)
      project_secrets = checkout_many_project_secrets(req)
      org_secrets = dt_secrets ++ secrets

      all_secrets = merge_checkout_secrets(project_secrets, org_secrets)

      CheckoutManyResponse.new(metadata: status_ok(req), secrets: all_secrets)
    else
      CheckoutManyResponse.new(
        metadata: status_not_ok(req, :FAILED_PRECONDITION, "checkout_metadata is required")
      )
    end
  end

  defp checkout_many_dt_secrets(req) do
    alias Secrethub.DeploymentTargets.Store, as: DTStore
    alias Secrethub.DeploymentTargets.Mapper, as: DTMapper

    names = Map.get(req, :names, [])
    secrets = DTStore.list_by_names(req.metadata.org_id, names)

    checkout_params = Map.from_struct(req.checkout_metadata)
    secrets = DTStore.checkout_many(secrets, checkout_params)
    secrets |> List.wrap() |> Enum.into([], &DTMapper.encode/1)
  end

  defp checkout_many_project_secrets(req) do
    alias Secrethub.ProjectSecrets.Store, as: ProjectSecretStore
    alias Secrethub.ProjectSecrets.Mapper, as: ProjectSecretMapper

    names = Map.get(req, :names, [])
    secrets = ProjectSecretStore.list_by_names(req.metadata.org_id, req.project_id, names)

    checkout_params = Map.from_struct(req.checkout_metadata)
    secrets = ProjectSecretStore.checkout_many(secrets, checkout_params)
    secrets |> List.wrap() |> Enum.into([], &ProjectSecretMapper.encode/1)
  end

  defp merge_checkout_secrets(project_secrets, org_secrets) do
    filtered_org_secrets =
      org_secrets
      |> Enum.filter(fn secret ->
        not Enum.any?(project_secrets, fn project_secret ->
          project_secret.metadata.name == secret.metadata.name
        end)
      end)

    project_secrets ++ filtered_org_secrets
  end

  defp load_many_project_secrets(req) do
    alias Secrethub.ProjectSecrets.Store, as: ProjectSecretStore
    alias Secrethub.ProjectSecrets.Mapper, as: ProjectSecretMapper

    names = Map.get(req, :names, [])
    secrets = ProjectSecretStore.list_by_names(req.metadata.org_id, req.project_id, names)

    secrets |> List.wrap() |> Enum.into([], &ProjectSecretMapper.encode/1)
  end

  defp load_many_dt_secrets(req) do
    alias Secrethub.DeploymentTargets.Store, as: DTStore
    alias Secrethub.DeploymentTargets.Mapper, as: DTMapper

    names = Map.get(req, :names, [])
    secrets = DTStore.list_by_names(req.metadata.org_id, names)
    secrets |> List.wrap() |> Enum.into([], &DTMapper.encode/1)
  end

  def destroy(req, _), do: observe("destroy", req.secret_level, fn -> destroy(req) end)

  defp destroy(request = %API.DestroyRequest{secret_level: :DEPLOYMENT_TARGET}) do
    Secrethub.DeploymentTargets.Actions.handle_destroy(request)
  end

  defp destroy(request = %API.DestroyRequest{secret_level: :PROJECT}) do
    Secrethub.ProjectSecrets.Actions.handle_destroy(request)
  end

  defp destroy(req) do
    with {:ok, secret} <- find_secret(Map.put(req, :project_id, "")),
         {:ok, _} <- Secrethub.Secret.delete(secret) do
      DestroyResponse.new(metadata: status_ok(req), id: secret.id)
    else
      {:error, :not_found} ->
        DestroyResponse.new(metadata: status_not_ok(req, :NOT_FOUND))

      {:error, :failed_precondition, message} ->
        DestroyResponse.new(metadata: status_not_ok(req, :FAILED_PRECONDITION, message))
    end
  end

  def generate_open_id_connect_token(req, _),
    do:
      observe("generate_open_id_connect_token", nil, fn -> generate_open_id_connect_token(req) end)

  defp generate_open_id_connect_token(req) do
    case Secrethub.OpenIDConnect.JWT.generate_and_sign(req) do
      {:ok, token} ->
        Secrethub.OpenIDConnect.Utilization.add_token_generated(req.org_username)
        GenerateOpenIDConnectTokenResponse.new(token: token)

      e ->
        Logger.error("Failed to generate a signed JWT token")
        raise GRPC.RPCError, status: :internal, message: inspect(e)
    end
  end

  def create_encrypted(request, _stream),
    do: observe("create_encrypted", :DEPLOYMENT_TARGET, fn -> create_encrypted(request) end)

  defp create_encrypted(
         request = %API.CreateEncryptedRequest{
           secret: %API.Secret{metadata: %API.Secret.Metadata{level: :DEPLOYMENT_TARGET}}
         }
       ) do
    Secrethub.DeploymentTargets.Actions.handle_create_encrypted(request)
  end

  defp create_encrypted(_request) do
    raise GRPC.RPCError, status: :unimplemented, message: "Not yet implemented"
  end

  def update_encrypted(request, _stream),
    do: observe("update_encrypted", :DEPLOYMENT_TARGET, fn -> update_encrypted(request) end)

  defp update_encrypted(
         request = %API.UpdateEncryptedRequest{
           secret: %API.Secret{metadata: %API.Secret.Metadata{level: :DEPLOYMENT_TARGET}}
         }
       ) do
    Secrethub.DeploymentTargets.Actions.handle_update_encrypted(request)
  end

  defp update_encrypted(_request) do
    raise GRPC.RPCError, status: :unimplemented, message: "Not yet implemented"
  end

  def get_key(_, _) do
    case Secrethub.KeyVault.current_key() do
      {:ok, {key_id, public_key}} ->
        API.GetKeyResponse.new(id: key_id, key: public_key)

      {:error, %Secrethub.KeyVault.Error{reason: reason}} ->
        Logger.error("GetKey failed: #{inspect(reason)}")
        raise GRPC.RPCError, status: :internal, message: "Cannot fetch key"
    end
  end

  def get_jwt_config(req, _stream) do
    alias InternalApi.Secrethub.GetJWTConfigResponse

    config =
      case req.project_id do
        "" -> JWTConfiguration.get_org_config(req.org_id)
        project_id -> JWTConfiguration.get_project_config(req.org_id, project_id)
      end

    case config do
      {:ok, config} ->
        claims = convert_claims_to_proto(config.claims)

        GetJWTConfigResponse.new(
          org_id: config.org_id,
          project_id: config.project_id,
          claims: claims,
          is_active: config.is_active
        )

      {:error, :org_id_required} ->
        raise GRPC.RPCError, status: :invalid_argument, message: "Organization ID is required"

      {:error, :project_id_required} ->
        raise GRPC.RPCError, status: :invalid_argument, message: "Project ID is required"

      {:error, reason} ->
        raise GRPC.RPCError,
          status: :internal,
          message: "Failed to get JWT config: #{inspect(reason)}"
    end
  end

  def update_jwt_config(req, _stream) do
    alias InternalApi.Secrethub.UpdateJWTConfigResponse

    converted_claims = convert_proto_to_claims(req.claims)

    result =
      case req.project_id do
        "" ->
          JWTConfiguration.create_or_update_org_config(req.org_id, converted_claims)

        project_id ->
          JWTConfiguration.create_or_update_project_config(
            req.org_id,
            project_id,
            converted_claims
          )
      end

    case result do
      {:ok, config} ->
        UpdateJWTConfigResponse.new(
          org_id: config.org_id,
          project_id: config.project_id
        )

      {:error, :org_id_required} ->
        raise GRPC.RPCError, status: :invalid_argument, message: "Organization ID is required"

      {:error, :project_id_required} ->
        raise GRPC.RPCError, status: :invalid_argument, message: "Project ID is required"

      {:error, reason} ->
        raise GRPC.RPCError,
          status: :internal,
          message: "Failed to update JWT config: #{inspect(reason)}"
    end
  end

  defp find_secret(req) do
    cond do
      Map.get(req, :id, "") != "" ->
        Secrethub.Secret.find(req.metadata.org_id, req.id, req.project_id)

      Map.get(req, :name, "") != "" ->
        Secrethub.Secret.find_by_name(req.metadata.org_id, req.name, req.project_id)

      true ->
        {:error, :failed_precondition, "Name or ID must be provided"}
    end
  end

  defp serialize(secret, ignore_contents?) do
    alias InternalApi.Secrethub.Secret

    org_config_params = Secrethub.Utils.to_org_config_params(secret)

    Secret.new(
      metadata:
        Secret.Metadata.new(
          id: secret.id,
          name: secret.name,
          description: secret.description,
          org_id: secret.org_id,
          created_at: timestamp(secret.inserted_at),
          updated_at: timestamp(secret.updated_at),
          checkout_at: timestamp(secret.used_at),
          created_by: secret.created_by,
          updated_by: secret.created_by,
          checkout_by: to_checkout_by(secret.used_by)
        ),
      data: serialize_data(secret, ignore_contents?),
      org_config: Secret.OrgConfig.new(org_config_params)
    )
  end

  defp serialize_data(_data, _ignore_contents? = true), do: nil

  defp serialize_data(secret, _ignore_contents? = false) do
    alias InternalApi.Secrethub.Secret

    Secret.Data.new(
      env_vars:
        Enum.map(secret.content.env_vars || [], fn e ->
          Secret.EnvVar.new(name: e.name, value: e.value)
        end),
      files:
        Enum.map(secret.content.files || [], fn e ->
          Secret.File.new(path: e.path, content: e.content)
        end)
    )
  end

  defp to_checkout_by(nil), do: InternalApi.Secrethub.CheckoutMetadata.new()

  defp to_checkout_by(used_by) do
    alias InternalApi.Secrethub.CheckoutMetadata

    Enum.map(used_by, fn {key, value} -> {String.to_existing_atom(key), value} end)
    |> CheckoutMetadata.new()
  end

  defp timestamp(nil), do: Google.Protobuf.Timestamp.new()

  defp timestamp(time),
    do:
      Google.Protobuf.Timestamp.new(
        seconds: DateTime.from_naive!(time, "Etc/UTC") |> DateTime.to_unix()
      )

  defp observe(action_name, level, f) do
    Watchman.benchmark(observe_name(action_name, "duration", level), fn ->
      try do
        result = f.()

        if Map.get(result, :metadata) do
          case result.metadata.status.code do
            :OK ->
              Watchman.increment(observe_name(action_name, "success", level))
              result

            _ ->
              Watchman.increment(observe_name(action_name, "failure", level))
              result
          end
        else
          Watchman.increment(observe_name(action_name, "success", level))
          result
        end
      rescue
        e ->
          Watchman.increment(observe_name(action_name, "panic", level))
          Kernel.reraise(e, __STACKTRACE__)
      end
    end)
  end

  defp observe_name(action_name, metric_type, nil),
    do: "internal_secrethub.#{action_name}.#{metric_type}"

  defp observe_name(action_name, metric_type, level),
    do: {"internal_secrethub.#{action_name}.#{metric_type}", [level_tag(level)]}

  defp level_tag(:DEPLOYMENT_TARGET), do: "deployment_target"
  defp level_tag(:PROJECT), do: "project"
  defp level_tag(:ORGANIZATION), do: "organization"

  defp status_ok(req) do
    ResponseMeta.new(
      api_version: req.metadata.api_version,
      kind: req.metadata.kind,
      req_id: req.metadata.req_id,
      org_id: req.metadata.org_id,
      user_id: req.metadata.user_id,
      status: ResponseMeta.Status.new(code: :OK)
    )
  end

  defp status_not_ok(req, code, message \\ "") do
    ResponseMeta.new(
      api_version: req.metadata.api_version,
      kind: req.metadata.kind,
      req_id: req.metadata.req_id,
      org_id: req.metadata.org_id,
      user_id: req.metadata.user_id,
      status: ResponseMeta.Status.new(code: code, message: message)
    )
  end

  defp convert_claims_to_proto(claims_config) when is_list(claims_config) do
    Enum.map(claims_config, fn config ->
      %InternalApi.Secrethub.ClaimConfig{
        name: config["name"],
        is_active: config["is_active"] || false,
        is_system_claim: config["is_system_claim"] || false,
        is_mandatory: config["is_mandatory"] || false,
        description: config["description"],
        is_aws_tag: config["is_aws_tag"] || false
      }
    end)
  end

  defp convert_proto_to_claims(proto_claims) when is_list(proto_claims) do
    Enum.map(proto_claims, fn config ->
      %{
        "name" => config.name,
        "is_active" => config.is_active,
        "description" => config.description,
        "is_mandatory" => config.is_mandatory,
        "is_aws_tag" => config.is_aws_tag,
        "is_system_claim" => config.is_system_claim
      }
    end)
  end
end
