defmodule Notifications.Models.Rule do
  require Logger

  use Ecto.Schema
  import Ecto.Changeset
  alias Notifications.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rules" do
    belongs_to(:notification, Notifications.Models.Notification)
    has_many(:patterns, Notifications.Models.Pattern, on_delete: :delete_all)

    field(:org_id, :binary_id)

    field(:name, :string)
    field(:slack, :map)
    field(:email, :map)
    field(:webhook, :map)

    timestamps()
  end

  def new(org_id, notification_id, name, slack, email, webhook) do
    %__MODULE__{
      org_id: org_id,
      notification_id: notification_id,
      name: name,
      slack: slack,
      email: email,
      webhook: webhook
    }
  end

  def decode_slack(map) do
    Util.Proto.deep_new!(
      Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Slack,
      map,
      string_keys_to_atoms: true
    )
  end

  def decode_email(map) do
    Util.Proto.deep_new!(
      Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email,
      map,
      string_keys_to_atoms: true
    )
  end

  def decode_webhook(map) do
    Util.Proto.deep_new!(
      Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Webhook,
      map,
      string_keys_to_atoms: true
    )
  end

  #
  # Lookup
  #

  def find(id) do
    case Repo.get_by(__MODULE__, id: id) do
      nil -> {:error, :not_found}
      notification -> {:ok, notification}
    end
  end

  def changeset(rule, params \\ %{}) do
    rule
    |> cast(params, [:org_id, :notification_id, :name, :slack, :email, :webhook])
    |> validate_required([:org_id, :notification_id, :name, :slack, :email, :webhook])
  end
end
