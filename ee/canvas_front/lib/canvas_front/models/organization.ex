defmodule CanvasFront.Models.Organization do
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

    case CanvasFront.Cache.get_all(cache_keys) do
      {:ok, values} ->
        values = Enum.map(values, fn value -> CanvasFront.Cache.decode(value) end)
        org = Enum.zip(fields, values)
        struct!(__MODULE__, org)

      {:not_cached, _} ->
        find(id, fields, false)
    end
  end

  def find_(id, _fields, false) do
    req = %InternalApi.Organization.DescribeRequest{org_id: id}

    {:ok, res} = Stub.describe(channel(), req, timeout: 30_000)

    if res.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
      org = construct(res.organization)

      Enum.each(@cacheble_fields, fn {f, timeout} ->
        CanvasFront.Cache.set(
          cache_key(id, f),
          Map.get(org, f) |> CanvasFront.Cache.encode(),
          timeout
        )
      end)

      org
    else
      nil
    end
  end

  defp cache_key(id, field) do
    "#{@cache_prefix}-#{id}-#{field}"
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

  defp channel do
    organization_api_endpoint =
      Application.fetch_env!(:canvas_front, :organization_api_grpc_endpoint)

    {:ok, channel} = GRPC.Stub.connect(organization_api_endpoint)

    channel
  end
end
