defmodule Front.Clients.Billing do
  @moduledoc """
  Client for communication with the Billing service.
  """
  require Logger

  alias InternalApi.{
    Billing.AcknowledgeTrialEndRequest,
    Billing.AcknowledgeTrialEndResponse,
    Billing.BillingService.Stub,
    Billing.CanSetupOrganizationRequest,
    Billing.CanSetupOrganizationResponse,
    Billing.CanUpgradePlanRequest,
    Billing.CanUpgradePlanResponse,
    Billing.CreditsUsageRequest,
    Billing.CreditsUsageResponse,
    Billing.CurrentSpendingRequest,
    Billing.CurrentSpendingResponse,
    Billing.DescribeProjectRequest,
    Billing.DescribeProjectResponse,
    Billing.DescribeSpendingRequest,
    Billing.DescribeSpendingResponse,
    Billing.GetBudgetRequest,
    Billing.GetBudgetResponse,
    Billing.ListDailyCostsRequest,
    Billing.ListDailyCostsResponse,
    Billing.ListInvoicesRequest,
    Billing.ListInvoicesResponse,
    Billing.ListProjectsRequest,
    Billing.ListProjectsResponse,
    Billing.ListSpendingSeatsRequest,
    Billing.ListSpendingSeatsResponse,
    Billing.ListSpendingsRequest,
    Billing.ListSpendingsResponse,
    Billing.OrganizationStatusRequest,
    Billing.SetBudgetRequest,
    Billing.SetBudgetResponse,
    Billing.SetupOrganizationRequest,
    Billing.SetupOrganizationResponse,
    Billing.UpgradePlanRequest,
    Billing.UpgradePlanResponse
  }

  alias Util.Proto
  import Front.Utils, only: [ok: 1]

  @doc """
  Returns the current version of the billing service cache.
  Every protobuf file that is used in the billing service should be included in the version.
  Otherwise, strange errors may occur when deserializing.
  """
  @version [
             "lib/internal_api/billing.pb.ex",
             "lib/internal_api/usage.pb.ex"
           ]
           |> Enum.map_join(".", fn file ->
             File.read(file)
             |> elem(1)
             |> then(&:crypto.hash(:md5, &1))
           end)
           |> Base.encode64()

  @type rpc_request(response_type) :: response_type | Map.t()
  @type rpc_response(response_type) :: {:ok, response_type} | {:error, GRPC.RPCError.t()}

  def organization_status(org_id) do
    %{org_id: org_id}
    |> decorate(OrganizationStatusRequest)
    |> grpc_call(:organization_status, use_cache?: false)
    |> case do
      {:ok, response} ->
        construct_status(response)

      e ->
        Logger.error("Organization status check failed: #{inspect(e)}")

        %{plan: :error, last_charge_in_dollars: 0}
    end
  end

  @spec list_spendings(rpc_request(ListSpendingsRequest.t()), Keyword.t()) ::
          rpc_response(ListSpendingsResponse.t())
  def list_spendings(request, opts \\ []),
    do:
      request
      |> decorate(ListSpendingsRequest)
      |> grpc_call(:list_spendings, opts)

  @spec list_spending_seats(rpc_request(ListSpendingSeatsRequest.t()), Keyword.t()) ::
          rpc_response(ListSpendingSeatsResponse.t())
  def list_spending_seats(request, opts \\ []),
    do:
      request
      |> decorate(ListSpendingSeatsRequest)
      |> grpc_call(:list_spending_seats, opts)

  @spec describe_spending(rpc_request(DescribeSpendingRequest.t()), Keyword.t()) ::
          rpc_response(DescribeSpendingResponse.t())
  def describe_spending(request, opts \\ []),
    do:
      request
      |> decorate(DescribeSpendingRequest)
      |> grpc_call(:describe_spending, opts)

  @spec list_daily_costs(rpc_request(ListDailyCostsRequest.t()), Keyword.t()) ::
          rpc_response(ListDailyCostsResponse.t())
  def list_daily_costs(request, opts \\ []),
    do:
      request
      |> decorate(ListDailyCostsRequest)
      |> grpc_call(:list_daily_costs, opts)

  @spec list_invoices(rpc_request(ListInvoicesRequest.t()), Keyword.t()) ::
          rpc_response(ListInvoicesResponse.t())
  def list_invoices(request, opts \\ []),
    do:
      request
      |> decorate(ListInvoicesRequest)
      |> grpc_call(:list_invoices, opts)

  @spec current_spending(rpc_request(CurrentSpendingRequest.t()), Keyword.t()) ::
          rpc_response(CurrentSpendingResponse.t())
  def current_spending(request, opts \\ []),
    do:
      request
      |> decorate(CurrentSpendingRequest)
      |> grpc_call(:current_spending, opts)

  @spec get_budget(rpc_request(GetBudgetRequest.t()), Keyword.t()) ::
          rpc_response(GetBudgetResponse.t())
  def get_budget(request, opts \\ []),
    do:
      request
      |> decorate(GetBudgetRequest)
      |> grpc_call(:get_budget, opts)

  @spec set_budget(rpc_request(SetBudgetRequest.t()), Keyword.t()) ::
          rpc_response(SetBudgetResponse.t())
  def set_budget(request, opts \\ []),
    do:
      request
      |> decorate(SetBudgetRequest)
      |> grpc_call(:set_budget, Keyword.merge(opts, use_cache?: false))

  @spec credits_usage(rpc_request(CreditsUsageRequest.t()), Keyword.t()) ::
          rpc_response(CreditsUsageResponse.t())
  def credits_usage(request, opts \\ []),
    do:
      request
      |> decorate(CreditsUsageRequest)
      |> grpc_call(:credits_usage, opts)

  @spec can_upgrade_plan(rpc_request(CanUpgradePlanRequest.t()), Keyword.t()) ::
          rpc_response(CanUpgradePlanResponse.t())
  def can_upgrade_plan(request, opts \\ []),
    do:
      request
      |> decorate(CanUpgradePlanRequest)
      |> grpc_call(:can_upgrade_plan, Keyword.merge(opts, use_cache?: false))

  @spec upgrade_plan(rpc_request(UpgradePlanRequest.t()), Keyword.t()) ::
          rpc_response(UpgradePlanResponse.t())
  def upgrade_plan(request, opts \\ []),
    do:
      request
      |> decorate(UpgradePlanRequest)
      |> grpc_call(:upgrade_plan, Keyword.merge(opts, use_cache?: false))

  @spec list_projects(rpc_request(ListProjectsRequest.t()), Keyword.t()) ::
          rpc_response(ListProjectsResponse.t())
  def list_projects(request, opts \\ []),
    do:
      request
      |> decorate(ListProjectsRequest)
      |> grpc_call(:list_projects, opts)

  @spec describe_project(rpc_request(DescribeProjectRequest.t()), Keyword.t()) ::
          rpc_response(DescribeProjectResponse.t())
  def describe_project(request, opts \\ []),
    do:
      request
      |> decorate(DescribeProjectRequest)
      |> grpc_call(:describe_project, opts)

  @spec can_setup_organization(rpc_request(CanSetupOrganizationRequest.t())) ::
          rpc_response(CanSetupOrganizationResponse.t())
  def can_setup_organization(request, opts \\ []),
    do:
      request
      |> decorate(CanSetupOrganizationRequest)
      |> grpc_call(:can_setup_organization, Keyword.merge(opts, use_cache?: false))

  @spec setup_organization(rpc_request(SetupOrganizationRequest.t()), Keyword.t()) ::
          rpc_response(SetupOrganizationResponse.t())
  def setup_organization(request, opts \\ []),
    do:
      request
      |> decorate(SetupOrganizationRequest)
      |> grpc_call(:setup_organization, Keyword.merge(opts, use_cache?: false))

  @spec acknowledge_trial_end(rpc_request(AcknowledgeTrialEndRequest.t()), Keyword.t()) ::
          rpc_response(AcknowledgeTrialEndResponse.t())
  def acknowledge_trial_end(request, opts \\ []),
    do:
      request
      |> decorate(AcknowledgeTrialEndRequest)
      |> grpc_call(:acknowledge_trial_end, Keyword.merge(opts, use_cache?: false))

  def invalidate_cache(operation, params) do
    operation
    |> case do
      :describe_spending ->
        params
        |> decorate(DescribeSpendingRequest)
        |> then(&cache_key(operation, &1))
        |> Front.Cache.unset()

      :list_spendings ->
        params
        |> decorate(ListSpendingsRequest)
        |> then(&cache_key(operation, &1))
        |> Front.Cache.unset()

      :current_spending ->
        params
        |> decorate(CurrentSpendingRequest)
        |> then(&cache_key(operation, &1))
        |> Front.Cache.unset()

      :credits_usage ->
        params
        |> decorate(CreditsUsageRequest)
        |> then(&cache_key(operation, &1))
        |> Front.Cache.unset()

      _ ->
        Logger.info("Invalidating cache for operation #{inspect(operation)} is not supported")
    end
  end

  def cache_key(operation, params) when not is_list(params), do: cache_key(operation, [params])

  def cache_key(operation, params) do
    id =
      Enum.map_join(params, "-", &inspect(&1))
      |> :erlang.term_to_binary(compressed: 6)
      |> Base.encode64()

    "billing/#{@version}/#{operation}/#{id}"
  end

  defp construct_status(res) do
    %{
      plan: res.plan_type_slug,
      last_charge_in_dollars: 0
    }
  end

  defp decorate(request, schema) when is_struct(request, schema) do
    request
  end

  defp decorate(request, schema) do
    Proto.deep_new!(request, schema)
  end

  defp grpc_call(request, action, opts) do
    use_cache? = Keyword.get(opts, :use_cache?, true)
    reload_cache? = Keyword.get(opts, :reload_cache?, false)
    ttl = Keyword.get(opts, :cache_ttl, :timer.hours(1))
    key = cache_key(action, request)

    if reload_cache?, do: Front.Cache.unset(key)

    call = fn ->
      Watchman.benchmark("billing.#{action}.duration", fn ->
        channel()
        |> call_grpc(Stub, action, request, metadata(), timeout())
        |> tap(fn
          {:ok, response} when use_cache? ->
            Watchman.increment("billing.#{action}.success")
            set_cache(key, response, ttl)

          {:ok, _response} ->
            Watchman.increment("billing.#{action}.success")

          {:error, _} ->
            Watchman.increment("billing.#{action}.failure")
        end)
      end)
    end

    if use_cache? do
      Front.Cache.get(key)
      |> case do
        {:ok, result} ->
          Watchman.increment("billing.#{action}.cache_hit")
          ok(Front.Cache.decode(result))

        {:not_cached, _} ->
          Watchman.increment("billing.#{action}.cache_miss")
          call.()
      end
    else
      call.()
    end
  end

  defp set_cache(key, response, ttl) do
    Front.Async.run(fn ->
      Front.Cache.set(key, Front.Cache.encode(response), ttl)
    end)
  end

  defp call_grpc(error = {:error, err}, _, _, _, _, _) do
    Logger.error("""
    Unexpected error when connecting to Billing: #{inspect(err)}
    """)

    error
  end

  defp call_grpc({:ok, channel}, module, function_name, request, metadata, timeout) do
    if Front.saas?() do
      apply(module, function_name, [channel, request, [metadata: metadata, timeout: timeout]])
    else
      {:error, "Billing service is running only on saas instance"}
    end
  end

  defp channel do
    if Front.saas?() do
      Application.fetch_env!(:front, :billing_api_grpc_endpoint)
      |> GRPC.Stub.connect()
    else
      {:error, "Billing service is running only on saas instance"}
    end
  end

  defp timeout do
    30_000
  end

  defp metadata do
    nil
  end
end
