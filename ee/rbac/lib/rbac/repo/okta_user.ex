defmodule Rbac.Repo.OktaUser do
  use Rbac.Repo.Schema
  require Ecto.Query
  alias Ecto.Query
  alias Rbac.Repo
  import Ecto.Query

  @timestamps_opts [type: :utc_datetime]
  @derive {Jason.Encoder, only: [:payload]}

  @required_fields [
    :org_id,
    :integration_id,
    :payload,
    :state,
    :email
  ]

  @updatable_fields [
    :payload,
    :state,
    :email,
    :inserted_at,
    :updated_at,
    :user_id
  ]

  schema "okta_users" do
    belongs_to(:integration, Rbac.Repo.OktaIntegration)

    field(:org_id, :binary_id)
    field(:payload, :map)
    field(:state, Ecto.Enum, values: [:pending, :processed])
    field(:user_id, :binary_id)
    field(:email, :string)

    timestamps()
  end

  def new(integration, payload) do
    %__MODULE__{
      integration_id: integration.id,
      org_id: integration.org_id,
      payload: payload,
      email: email_from_payload(payload),
      state: :pending
    }
  end

  def find(integration, okta_user_id) do
    query = Query.where(Rbac.Repo.OktaUser, id: ^okta_user_id, integration_id: ^integration.id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def find_by_email(integration, email) do
    result =
      Repo.one(
        from(e in __MODULE__,
          where: e.integration_id == ^integration.id and e.email == ^email,
          limit: 1
        )
      )

    case result do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def find_by_user_id(user_id) do
    __MODULE__
    |> where([u], u.user_id == ^user_id)
    |> Repo.all()
  end

  @spec list(Rbac.Repo.OktaIntegration.t(), integer(), integer(), [Rbac.Okta.SCIM.Filter.t()]) ::
          any()
  def list(integration, start_index, count, filters) do
    users_query =
      Query.from(p in __MODULE__,
        where: p.integration_id == ^integration.id,
        limit: ^count,
        offset: ^start_index
      )

    total_count_query =
      Query.from(p in __MODULE__,
        where: p.integration_id == ^integration.id,
        select: count("*")
      )

    users_query = apply_list_filters(users_query, filters)
    total_count_query = apply_list_filters(total_count_query, filters)

    {Repo.all(users_query), Repo.one(total_count_query)}
  end

  @doc """
    List user ids of all active okta users within the given organization.
  """
  def list(org_id) do
    __MODULE__
    |> where([u], u.org_id == ^org_id)
    |> where([u], fragment("payload->'active'='true'"))
    |> select([u], u.user_id)
    |> Repo.all()
  end

  def create(integration, payload) do
    new(integration, payload)
    |> changeset()
    |> Rbac.Repo.insert()
  end

  def update(integration, user_id, payload) do
    new_data = %{payload: payload, state: :pending, email: email_from_payload(payload)}

    case find(integration, user_id) do
      {:ok, user} -> changeset(user, new_data) |> Rbac.Repo.update()
      e -> e
    end
  end

  @doc """
    Delete all okta users that were provisioned via given integration.
    This is used when deleting okta integration.
  """
  def delete_all(integration_id) do
    __MODULE__
    |> where([u], u.integration_id == ^integration_id)
    |> Rbac.Repo.delete_all()
  end

  def mark_as_processed(okta_user) do
    changeset(okta_user, %{state: :processed}) |> Rbac.Repo.update()
  end

  def name(okta_user) do
    okta_user.payload["displayName"]
  end

  def email(okta_user) do
    email_from_payload(okta_user.payload)
  end

  def active?(okta_user) do
    okta_user.payload["active"] == true
  end

  defp email_from_payload(payload) do
    email =
      payload["emails"]
      |> Enum.find(fn e -> e["primary"] == true end)

    email["value"] |> String.downcase()
  end

  def connect_user(okta_user, user_id) do
    changeset(okta_user, %{user_id: user_id}) |> Repo.update()
  end

  def disconnect_user(okta_user) do
    changeset(okta_user, %{user_id: nil}) |> Repo.update()
  end

  def reload_with_lock_and_transaction(okta_user_id, fun) do
    Rbac.Repo.transaction(
      fn ->
        query =
          Query.from(o in __MODULE__,
            where: o.id == ^okta_user_id,
            lock: "FOR UPDATE SKIP LOCKED"
          )

        okta_user = Repo.one(query)

        if okta_user do
          fun.(okta_user)
        end
      end,
      timeout: 60_000
    )
  end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, @updatable_fields)
    |> validate_required(@required_fields)
  end

  defp apply_list_filters(query, []) do
    query
  end

  defp apply_list_filters(query, [filter | rest]) do
    if filter.field_name == :username && filter.comparator == :eq do
      query
      |> Query.where([q], fragment("payload->>'userName' = ?", ^filter.value))
      |> apply_list_filters(rest)
    else
      query
    end
  end
end
