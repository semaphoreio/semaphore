defmodule PipelinesAPI.OrganizationsClient do
  @moduledoc """
  gRPC client for account-level organization creation: Organization.IsValid,
  Billing.CanSetupOrganization, and Organization.Create.
  """

  alias InternalApi.Billing.{BillingService, CanSetupOrganizationRequest}
  alias InternalApi.Organization.{OrganizationService, CreateRequest, Organization}
  alias PipelinesAPI.Util.{Log, Metrics, ToTuple}

  require Logger

  defp org_url, do: System.get_env("INTERNAL_API_URL_ORGANIZATION")
  defp billing_url, do: System.get_env("INTERNAL_API_URL_BILLING")
  defp opts, do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

  # Organization.IsValid — name/username validation (mirrors validate_organization).
  @spec is_valid(String.t(), String.t(), String.t()) :: :ok | {:error, tuple()}
  def is_valid(name, username, owner_id) do
    case Wormhole.capture(__MODULE__, :is_valid_, [name, username, owner_id],
           stacktrace: true,
           skip_log: true
         ) do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "is_valid")
    end
  end

  def is_valid_(name, username, owner_id) do
    {:ok, channel} = GRPC.Stub.connect(org_url())

    # Organization.new/1, not a struct literal: the literal leaves every other
    # field nil and protobuf raises Protobuf.InvalidError on encode (e.g.
    # "Organization#avatar_url is invalid!"); new/1 fills proto3 defaults.
    request = Organization.new(name: name, org_username: username, owner_id: owner_id)

    Metrics.benchmark("PipelinesAPI.organizations_client", ["is_valid"], fn ->
      channel
      |> OrganizationService.Stub.is_valid(request, opts())
      |> process_is_valid()
    end)
  end

  # Billing gate — boolean allow/deny for the user, no inline payment.
  @spec can_setup_organization(String.t()) :: :ok | {:error, tuple()}
  def can_setup_organization(owner_id) do
    case Wormhole.capture(__MODULE__, :can_setup_organization_, [owner_id],
           stacktrace: true,
           skip_log: true
         ) do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "can_setup_organization")
    end
  end

  def can_setup_organization_(owner_id) do
    {:ok, channel} = GRPC.Stub.connect(billing_url())

    Metrics.benchmark("PipelinesAPI.organizations_client", ["can_setup_organization"], fn ->
      channel
      |> BillingService.Stub.can_setup_organization(
        %CanSetupOrganizationRequest{owner_id: owner_id},
        opts()
      )
      |> process_billing()
    end)
  end

  # Organization.Create (mirrors organization_setup).
  @spec create(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, tuple()}
  def create(creator_id, name, username) do
    case Wormhole.capture(__MODULE__, :create_, [creator_id, name, username],
           stacktrace: true,
           skip_log: true
         ) do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "create")
    end
  end

  def create_(creator_id, name, username) do
    {:ok, channel} = GRPC.Stub.connect(org_url())

    Metrics.benchmark("PipelinesAPI.organizations_client", ["create"], fn ->
      channel
      |> OrganizationService.Stub.create(
        %CreateRequest{
          creator_id: creator_id,
          organization_name: name,
          organization_username: username
        },
        opts()
      )
      |> process_create()
    end)
  end

  # Response handling

  defp process_is_valid({:ok, %{is_valid: true}}), do: :ok

  defp process_is_valid({:ok, %{is_valid: false, errors: message}}),
    do: ToTuple.user_error(format_organization_api_error(message))

  defp process_is_valid({:error, %GRPC.RPCError{message: message}}),
    do: Log.internal_error(message, "is_valid", "Organization")

  defp process_is_valid(error), do: Log.internal_error(error, "is_valid", "Organization")

  defp process_billing({:ok, %{allowed: true}}), do: :ok

  defp process_billing({:ok, %{allowed: false, errors: errors}}),
    do: ToTuple.user_error(format_errors(errors, "Account check failed"))

  defp process_billing({:error, %GRPC.RPCError{message: message}}),
    do: Log.internal_error(message, "can_setup_organization", "Billing")

  defp process_billing(error), do: Log.internal_error(error, "can_setup_organization", "Billing")

  defp process_create({:ok, %{status: status, organization: org}}) do
    if status && status.code == InternalApi.ResponseStatus.Code.value(:OK) do
      {:ok, org}
    else
      message = (status && status.message) || "Organization creation failed"
      ToTuple.user_error(format_organization_api_error(message))
    end
  end

  defp process_create({:error, %GRPC.RPCError{message: message, status: status}})
       when status in [3, 6, 9],
       do: ToTuple.user_error(message)

  defp process_create({:error, %GRPC.RPCError{message: message}}),
    do: Log.internal_error(message, "create", "Organization")

  defp process_create(error), do: Log.internal_error(error, "create", "Organization")

  # Same customer-friendly mapping front uses (Front.Models.OrganizationOnboarding).
  defp format_organization_api_error(message) when is_binary(message) do
    if String.contains?(message, "Already taken"),
      do: "Organization name is already taken",
      else: message
  end

  defp format_organization_api_error(message), do: inspect(message)

  defp format_errors(errors, _fallback) when is_list(errors) and errors != [],
    do: Enum.join(errors, ", ")

  defp format_errors(_errors, fallback), do: fallback
end
