defmodule Front.Models.OrganizationOnboarding do
  require Logger
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  alias Front.Clients.Billing, as: BillingClient
  alias Front.Clients.Organization, as: OrganizationClient

  @type organization :: InternalApi.Organization.Organization.t()
  @type t :: %OrganizationOnboarding{
          id: String.t(),
          url: String.t(),
          name: String.t(),
          user_id: String.t()
        }

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:url, :string)
    field(:name, :string)
    field(:user_id, :string)
  end

  @fields ~w(url name user_id)a
  @required_fields @fields -- ~w(name)a

  def new(params) do
    %OrganizationOnboarding{}
    |> cast(params, @fields)
    |> validate_required(@required_fields)
    |> set_name
    |> case do
      %{valid?: false} = changeset ->
        errors =
          changeset.errors
          |> Enum.map_join(", ", fn {key, {message, _}} -> "#{key} #{message}" end)

        {:error, errors}

      changeset ->
        {:ok, apply_changes(changeset)}
    end
  end

  @doc """
  Create a new organization if validation passes.
  In case of an error, returns a customer friendly message.
  """
  def create_organization({:ok, model}), do: create_organization(model)
  def create_organization(error = {:error, _}), do: error

  def create_organization(model) do
    with :ok <- validate_organization(model),
         :ok <- validate_billing(model),
         {:ok, model} <- organization_setup(model) do
      {:ok, model}
    else
      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Performs checks to indicate if the organization setup is complete.
  """
  @spec wait_for_organization(String.t(), String.t()) :: :ok | {:error, String.t()}
  def wait_for_organization(org_id, user_id) do
    with :ok <- wait_for_billing(org_id),
         :ok <- wait_for_rbac(org_id, user_id) do
      :ok
    else
      {:error, message} ->
        {:error, message}
    end
  end

  defp wait_for_billing(org_id) do
    Front.Clients.Billing.organization_status(org_id)
    |> case do
      %{plan: :error} -> {:error, "Billing not ready yet"}
      _ -> :ok
    end
  rescue
    e ->
      Logger.error("Billing check failed: #{inspect(e)}")
      {:error, "Billing check failed"}
  end

  defp wait_for_rbac(org_id, user_id) do
    Front.RBAC.Members.is_org_member?(org_id, user_id)
    |> case do
      false -> {:error, "RBAC not ready yet"}
      true -> :ok
    end
  end

  defp set_name(changeset) do
    case get_field(changeset, :url) do
      nil -> changeset
      url -> put_change(changeset, :name, url)
    end
  end

  @spec validate_organization(model :: t()) :: :ok | {:error, String.t()}
  defp validate_organization(model) do
    OrganizationClient.is_valid(%{
      name: model.name,
      org_username: model.url,
      owner_id: model.user_id
    })
    |> case do
      {:ok, %{is_valid: true}} ->
        :ok

      {:ok, %{is_valid: false, errors: message}} ->
        {:error, format_organization_api_error(message)}

      {:error, _} ->
        {:error, "Organization name check failed"}
    end
  end

  @spec validate_billing(model :: t()) :: :ok | {:error, String.t()}
  defp validate_billing(model) do
    if Front.saas?() do
      BillingClient.can_setup_organization(%{
        owner_id: model.user_id
      })
      |> case do
        {:ok, %{allowed: true}} -> :ok
        {:ok, %{allowed: false, errors: messages}} -> {:error, Enum.join(messages, ", ")}
        {:error, _} -> {:error, "Account check failed"}
      end
    else
      :ok
    end
  end

  @spec organization_setup(model :: t()) :: {:ok, t()} | {:error, String.t()}
  defp organization_setup(model) do
    ok_code = InternalApi.ResponseStatus.Code.value(:OK)

    OrganizationClient.create(%{
      organization_name: model.name,
      organization_username: model.url,
      creator_id: model.user_id
    })
    |> case do
      {:ok, %{organization: organization, status: %{code: ^ok_code}}} ->
        {:ok, %{model | id: organization.org_id}}

      {:ok, %{status: %{code: _, message: message}}} ->
        {:error, format_organization_api_error(message)}

      {:error, e} ->
        Logger.error("Organization creation failed: #{inspect(e)}")
        {:error, "Organization creation failed"}
    end
  end

  defp format_organization_api_error(error_message) do
    if String.contains?(error_message, "Already taken") do
      "Organization name is already taken"
    else
      error_message
    end
  end
end
