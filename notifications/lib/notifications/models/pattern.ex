defmodule Notifications.Models.Pattern do
  require Logger

  use Ecto.Schema
  import Ecto.Changeset
  alias Notifications.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "patterns" do
    belongs_to(:rule, Notifications.Models.Rule)
    field(:org_id, :binary_id)

    field(:term, :string)
    field(:regex, :boolean)
    field(:type, :string)

    timestamps()
  end

  def new(org_id, rule_id, terms, type) when is_list(terms) do
    Enum.map(terms, fn term -> new(org_id, rule_id, term, type) end)
  end

  def new(org_id, rule_id, term, type) do
    if regex?(term) do
      %__MODULE__{
        org_id: org_id,
        rule_id: rule_id,
        # remove the first and last '/'
        term: String.slice(term, 1..-2),
        regex: true,
        type: type
      }
    else
      %__MODULE__{
        org_id: org_id,
        rule_id: rule_id,
        term: term,
        regex: false,
        type: type
      }
    end
  end

  def regex?(term) do
    term =~ ~r/^\/.*\/$/
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

  def changeset(pattern, params \\ %{}) do
    pattern
    |> cast(params, [
      :org_id,
      :notification_id,
      :name,
      :slack,
      :email,
      :webhook
    ])
    |> validate_required([
      :org_id,
      :notification_id,
      :name,
      :slack,
      :email,
      :webhook
    ])
  end
end
