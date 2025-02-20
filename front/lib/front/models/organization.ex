defmodule Front.Models.Organization do
  alias Front.Sufix
  alias InternalApi.Organization.OrganizationService.Stub

  require Logger

  @fields [
    :id,
    :name,
    :username,
    :avatar_url,
    :created_at,
    :open_source,
    :restricted,
    :ip_allow_list,
    :owner_id,
    :deny_member_workflows,
    :deny_non_member_workflows
  ]

  @cache_prefix "organization-v2-"

  @cacheble_fields %{
    :username => :timer.minutes(60),
    :restricted => :timer.minutes(60),
    :created_at => :timer.minutes(1440)
  }

  defstruct @fields

  def find(id, fields \\ @fields, use_cache \\ true)

  def find(nil, _fields, _use_cache) do
    nil
  end

  def find(id, fields, use_cache) do
    Watchman.benchmark("fetch_org.duration", fn ->
      find_(id, fields, use_cache)
    end)
  end

  def find_(id, fields, true) do
    cache_keys = Enum.map(fields, fn f -> cache_key(id, f) end)

    case Front.Cache.get_all(cache_keys) do
      {:ok, values} ->
        values = Enum.map(values, fn value -> Front.Cache.decode(value) end)
        org = Enum.zip(fields, values)
        struct!(__MODULE__, org)

      {:not_cached, _} ->
        find(id, fields, false)
    end
  end

  def find_(id, _fields, false) do
    alias InternalApi.Organization.OrganizationService.Stub
    req = InternalApi.Organization.DescribeRequest.new(org_id: id)

    endpoint = Application.fetch_env!(:front, :organization_api_grpc_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    {:ok, res} = Stub.describe(channel, req, timeout: 30_000)

    if res.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
      org = construct(res.organization)

      Enum.each(@cacheble_fields, fn {f, timeout} ->
        Front.Cache.set(cache_key(id, f), Map.get(org, f) |> Front.Cache.encode(), timeout)
      end)

      org
    else
      nil
    end
  end

  defp cache_key(id, field) do
    "#{@cache_prefix}-#{id}-#{field}"
  end

  def create(attributes, metadata) do
    create_req(attributes, metadata, 0)
  end

  def create(attributes, metadata, iteration) do
    case create_req(attributes, metadata, iteration) do
      {:ok, org} ->
        {:ok, org}

      {:error, msg, org} ->
        next_iteration = iteration + 1

        if String.contains?(msg, "Already taken") && Sufix.contains?(next_iteration) do
          create(attributes, metadata, next_iteration)
        else
          {:error, msg, org}
        end
    end
  end

  defp create_req(attributes, metadata, iteration) do
    Watchman.benchmark("create_org.duration", fn ->
      name = Keyword.get(attributes, :name)
      username = Keyword.get(attributes, :username) |> Sufix.with_sufix(iteration)
      creator_id = Keyword.get(attributes, :creator_id)

      req =
        InternalApi.Organization.CreateRequest.new(
          organization_name: name,
          organization_username: username,
          creator_id: creator_id
        )

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:front, :organization_api_grpc_endpoint))

      {:ok, res} =
        InternalApi.Organization.OrganizationService.Stub.create(channel, req,
          metadata: metadata,
          timeout: 30_000
        )

      if res.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
        {:ok, construct(res.organization)}
      else
        {:error, res.status.message, construct(res.organization)}
      end
    end)
  end

  def update(organization, fields, metadata \\ nil) do
    Watchman.benchmark("update_org.duration", fn ->
      req =
        InternalApi.Organization.UpdateRequest.new(
          organization:
            InternalApi.Organization.Organization.new(
              org_id: organization.id,
              name: fields[:name],
              org_username: fields[:username],
              ip_allow_list: fields[:ip_allow_list],
              deny_member_workflows: fields[:deny_member_workflows],
              deny_non_member_workflows: fields[:deny_non_member_workflows]
            )
        )

      with {:ok, channel} <-
             GRPC.Stub.connect(Application.fetch_env!(:front, :organization_api_grpc_endpoint)),
           {:ok, res} <- Stub.update(channel, req, metadata: metadata, timeout: 30_000) do
        {:ok, construct(res.organization)}
      else
        {:error, %GRPC.RPCError{message: message} = e} ->
          Logger.error("Organization update failed: #{inspect(e)}")
          {:error, message}

        e ->
          Logger.error("Organization update failed with unknown error: #{inspect(e)}")
          {:error, "unknown internal error"}
      end
    end)
  end

  def destroy(organization, metadata \\ nil) do
    Watchman.benchmark("destroy_org.duration", fn ->
      req = InternalApi.Organization.DestroyRequest.new(org_id: organization.id)

      Stub.destroy(channel(), req, options(metadata))
    end)
  end

  def list(user_id) do
    Watchman.benchmark("list_orgs.duration", fn ->
      {:ok, org_ids} = Front.RBAC.Members.list_accessible_orgs(user_id)

      req = InternalApi.Organization.DescribeManyRequest.new(org_ids: org_ids)

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:front, :organization_api_grpc_endpoint))

      case InternalApi.Organization.OrganizationService.Stub.describe_many(channel, req,
             timeout: 30_000
           ) do
        {:ok, res} ->
          Enum.map(res.organizations, fn organization ->
            construct(organization)
          end)

        e ->
          Logger.error(
            "Error while describing organizations #{inspect(org_ids)}. Value returned: #{inspect(e)}"
          )

          nil
      end
    end)
  end

  def list_suspensions(org_id, metadata \\ nil) do
    Watchman.benchmark("list_suspensions.duration", fn ->
      req = InternalApi.Organization.ListSuspensionsRequest.new(org_id: org_id)

      {:ok, res} =
        Stub.list_suspensions(
          channel(),
          req,
          options(metadata)
        )

      if res.status.code == Google.Rpc.Code.value(:OK) do
        construct_suspensions(res.suspensions)
      else
        Logger.error("Error when listing suspensions: #{res.status.message}")
        nil
      end
    end)
  end

  def repository_integrators(org_id) do
    Watchman.benchmark("list_suspensions.duration", fn ->
      req = InternalApi.Organization.RepositoryIntegratorsRequest.new(org_id: org_id)

      case Stub.repository_integrators(channel(), req, options(nil)) do
        {:ok, res} ->
          {:ok, res}

        {:error, error} ->
          Logger.error(
            "Error when listing repository integrators for #{org_id}: #{inspect(error)}"
          )

          {:error, nil}
      end
    end)
  end

  def construct(raw_org) do
    %__MODULE__{
      :name => raw_org.name,
      :username => raw_org.org_username,
      :avatar_url => raw_org.avatar_url,
      :id => raw_org.org_id,
      :created_at => DateTime.from_unix!(raw_org.created_at.seconds),
      :open_source => raw_org.open_source,
      :restricted => raw_org.restricted,
      :ip_allow_list => raw_org.ip_allow_list,
      :owner_id => raw_org.owner_id,
      :deny_member_workflows => raw_org.deny_member_workflows,
      :deny_non_member_workflows => raw_org.deny_non_member_workflows
    }
  end

  defp construct_suspensions(suspensions) do
    suspensions
    |> Enum.map(fn sus ->
      InternalApi.Organization.Suspension.Reason.key(sus.reason)
    end)
  end

  defp options(metadata) do
    [timeout: 30_000, metadata: metadata]
  end

  defp channel do
    organization_api_endpoint =
      Application.fetch_env!(
        :front,
        :organization_api_grpc_endpoint
      )

    {:ok, channel} = GRPC.Stub.connect(organization_api_endpoint)

    channel
  end
end
