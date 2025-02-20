defmodule Front.Layout.Model do
  use TypedStruct
  require Logger

  alias Front.{Async, Models}

  typedstruct do
    field(:user, Models.User.t())
    field(:current_organization, Models.Organization.t())
    field(:organizations, [Models.Organization.t()])
    field(:unstarred_projects, [Models.Project.t()])
    field(:unstarred_dashboards, [Models.Dashboard.t()])
    field(:starred_items, [Map.t()])
    field(:suspensions, [Atom.t()])
    field(:permissions, [Map.t()])
  end

  def is_paid_plan?(model) do
    paid_plans =
      [:PAID, :GRANDFATHERED_CLASSIC, :PREPAID, :FLAT_ANNUAL]
      |> Enum.map(&InternalApi.Billing.PlanType.value/1)

    model
    |> Map.get(:plan, %{})
    |> case do
      %{plan_type: plan_type} ->
        plan_type in paid_plans

      _ ->
        false
    end
  end

  defmodule LoadParams do
    use TypedStruct

    typedstruct do
      field(:user_id, String.t(), enforce: true)
      field(:organization_id, String.t(), enforce: true)
    end
  end

  @cache_prefix "layout_model_v1"
  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()
  # Used to update the model cache version, when there is no change in the model file
  # @cache_hidden_version = "2"

  def cache_prefix, do: @cache_prefix
  def cache_version, do: @cache_version

  def encode(model), do: :erlang.term_to_binary(model)
  def decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])

  @spec get(LoadParams.t()) :: {:ok, __MODULE__.t()} | {:error, String.t()}
  def get(params, opts \\ []) do
    if opts[:force_cold_boot] == "true" do
      refresh(params)
    else
      fetch_from_cache(params)
    end
  end

  defp fetch_from_cache(params) do
    case Cacheman.get(:front, cache_key(params)) do
      {:ok, nil} ->
        Watchman.increment({"layout_model.cache.miss", []})
        refresh(params)

      {:ok, val} ->
        Watchman.increment({"layout_page_model.cache.hit", []})
        {:ok, decode(val), :from_cache}

      e ->
        e
    end
  end

  def cache_key(params) do
    "#{cache_prefix()}/#{cache_version()}/user_id=#{params.user_id}/organization_id=#{params.organization_id}/"
  end

  @spec refresh(LoadParams.t()) :: {:ok, t(), atom()}
  def refresh(params) do
    params |> invalidate()

    {:ok, data, _} = load_from_api(params)
    Cacheman.put(:front, cache_key(params), encode(data))

    Logger.info("[LAYOUT MODEL] Put #{cache_key(params)}")

    {:ok, data, :from_api}
  end

  @spec invalidate(LoadParams.t()) :: :ok
  def invalidate(params) do
    cache_key = params |> cache_key()

    if Cacheman.exists?(:front, cache_key) do
      {:ok, _} = Cacheman.delete(:front, cache_key)
      Logger.info("[LAYOUT MODEL] Invalidated #{cache_key}")
    else
      Logger.info("[LAYOUT MODEL] Invalidate #{cache_key} skipped because cache key is not found")
    end
  end

  @spec load_from_api(LoadParams.t()) :: {:ok, t(), atom()}
  def load_from_api(params) do
    fetch_current_organization =
      Async.run(fn ->
        Models.Organization.find(params.organization_id)
      end)

    fetch_all_organizations =
      Async.run(fn ->
        Models.Organization.list(params.user_id)
      end)

    fetch_projects =
      Async.run(fn ->
        Models.Project.list(params.organization_id, params.user_id)
      end)

    fetch_dashboards =
      Async.run(fn ->
        Models.Dashboard.list(params.user_id, params.organization_id)
      end)

    fetch_favorites =
      Async.run(fn ->
        Models.User.list_favorites(params.user_id, params.organization_id)
      end)

    fetch_user =
      Async.run(fn ->
        Models.User.find_with_opts(params.user_id, organization_id: params.organization_id)
      end)

    fetch_suspensions =
      Async.run(fn ->
        Models.Organization.list_suspensions(params.organization_id)
      end)

    fetch_permissions =
      Async.run(fn ->
        Front.RBAC.Permissions.has?(params.user_id, params.organization_id, [])
      end)

    {:ok, current_organization} = Async.await(fetch_current_organization)

    {:ok, {projects, _total_pages}} = Async.await(fetch_projects)
    {:ok, dashboards} = Async.await(fetch_dashboards)
    {:ok, favorites} = Async.await(fetch_favorites)
    {:ok, user} = Async.await(fetch_user)
    {:ok, suspensions} = Async.await(fetch_suspensions)
    {:ok, permissions} = Async.await(fetch_permissions)
    {:ok, organizations} = Async.await(fetch_all_organizations)

    starred_items =
      (projects ++ dashboards)
      |> filter_starred(favorites)
      |> sort_alphabetically()
      |> map_data("Starred")

    unstarred_projects =
      projects |> filter_unstarred(favorites) |> sort_alphabetically() |> map_data("Project")

    unstarred_dashboards =
      dashboards
      |> filter_unstarred(favorites)
      |> exclude_dashboards()
      |> sort_alphabetically()
      |> map_data("Dashboard")

    model =
      struct!(__MODULE__,
        user: user,
        current_organization: current_organization,
        organizations: organizations,
        unstarred_projects: unstarred_projects,
        unstarred_dashboards: unstarred_dashboards,
        starred_items: starred_items,
        suspensions: suspensions,
        permissions: permissions
      )

    {:ok, model, :from_api}
  end

  defp filter_starred(items, favorites) do
    items
    |> Enum.filter(fn item ->
      favorites |> Enum.find(fn favorite -> favorite.favorite_id == item.id end)
    end)
  end

  defp filter_unstarred(items, favorites) do
    items
    |> Enum.filter(fn item ->
      !Enum.find(favorites, fn favorite -> favorite.favorite_id == item.id end)
    end)
  end

  defp exclude_dashboards(dashboards) do
    dashboards
    |> exclude_one("my-work")
    |> exclude_one("everyones-activity")
  end

  defp sort_alphabetically(items) do
    items |> Enum.sort_by(&String.upcase(Map.get(&1, :name)))
  end

  defp exclude_one(list, name) do
    list |> Enum.filter(fn i -> i.name != name end)
  end

  defp map_data(items, type) when is_list(items) do
    Enum.map(items, fn item -> map_data(item, type) end)
  end

  defp map_data(item = %Front.Models.Project{}, _type) do
    %{id: item.id, type: "project", name: item.name, path: "/projects/#{item.name}"}
  end

  defp map_data(item = %Front.Models.Dashboard{}, _type) do
    %{id: item.id, type: "dashboard", name: item.name, path: "/dashboards/#{item.name}"}
  end
end
