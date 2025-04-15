defmodule Rbac.Repo.GroupManagementRequest do
  use Rbac.Repo.Schema

  import Ecto.Query, only: [where: 3, first: 2]
  import Rbac.Repo, only: [insert: 1, one: 1, update: 1]

  schema "group_management_request" do
    field(:state, Ecto.Enum, values: [:pending, :processing, :done, :failed], default: :pending)
    field(:user_id, :binary_id)
    field(:group_id, :binary_id)
    field(:action, Ecto.Enum, values: [:add_user, :remove_user, :destroy_group])
    field(:retries, :integer, default: 0)
    field(:requester_id, :binary_id)

    timestamps()
  end

  def load_req_for_processing do
    case __MODULE__
         |> where([req], req.state == ^:pending)
         |> first(:updated_at)
         |> one() do
      nil ->
        nil

      req ->
        {:ok, req} = req |> changeset(%{state: :processing}) |> update()
        req
    end
  end

  def create_new_request(user_ids, group_id, action, requester_id) when is_list(user_ids) do
    Enum.each(user_ids, &create_new_request(&1, group_id, action, requester_id))
  end

  def create_new_request(user_id, group_id, action, requester_id) do
    %__MODULE__{user_id: user_id, group_id: group_id, action: action, requester_id: requester_id}
    |> insert()
  end

  def create_destroy_group_request(group_id, requester_id) do
    # For destroy_group action, user_id is not needed
    create_new_request(nil, group_id, :destroy_group, requester_id)
  end

  def finish_processing(%__MODULE__{} = req) do
    req = fetch(req)

    {:ok, _req} =
      req
      |> changeset(%{state: :done})
      |> update()
  end

  @max_retries 3
  def failed_processing(%__MODULE__{} = req) do
    retries = req.retries + 1
    req = req |> fetch()
    next_state = if retries == @max_retries, do: :failed, else: :pending

    {:ok, _req} = req |> changeset(%{state: next_state, retries: retries}) |> update()
  end

  # We are fetching the request again, in case the one passed to the functions above is stale
  defp fetch(%__MODULE__{} = req), do: __MODULE__ |> where([req], req.id == ^req.id) |> one()

  defp changeset(req, attrs) do
    req
    |> cast(attrs, [:state, :retries])
  end
end
