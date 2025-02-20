# credo:disable-for-this-file
defmodule Rbac.Repo.RbacRefreshAllPermissionsRequest do
  use Rbac.Repo.Schema

  import Ecto.Query, only: [where: 3, first: 2]
  import Rbac.Repo, only: [insert: 1, one: 1, update: 1]

  schema "rbac_refresh_all_permissions_requests" do
    field(:state, Ecto.Enum, values: [:pending, :processing, :done, :failed], default: :pending)
    field(:organizations_updated, :integer, default: 0)
    field(:retries, :integer, default: 0)

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

  def create_new_request, do: %__MODULE__{} |> insert()

  def finish_processing_batch(%__MODULE__{} = req, update_orgs) do
    req = fetch(req)
    no_of_orgs = Rbac.FrontRepo.aggregate(Rbac.FrontRepo.Organization, :count, :id)
    processed_orgs = req.organizations_updated + update_orgs
    next_state = if processed_orgs >= no_of_orgs, do: :done, else: :pending

    {:ok, _req} =
      req
      |> changeset(%{state: next_state, organizations_updated: processed_orgs})
      |> update()
  end

  @max_retries 3
  def failed_processing(%__MODULE__{} = req) do
    req = req |> fetch()
    retries = req.retries + 1
    next_state = if retries == @max_retries, do: :failed, else: :pending

    {:ok, _req} = req |> changeset(%{state: next_state, retries: retries}) |> update()
  end

  # We are fetching the request again, in case the one passed to the functions above is stale
  defp fetch(%__MODULE__{} = req), do: __MODULE__ |> where([req], req.id == ^req.id) |> one()

  defp changeset(req, attrs) do
    req
    |> cast(attrs, [:state, :organizations_updated, :retries])
  end
end
