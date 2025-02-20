defmodule Audit.Event do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "events" do
    field(:resource, :integer)
    field(:operation, :integer)
    field(:timestamp, :utc_datetime)

    field(:org_id, :binary_id)
    field(:user_id, :binary_id)
    field(:username, :string)
    field(:ip_address, :string)

    field(:resource_id, :string)
    field(:resource_name, :string)

    field(:metadata, :map)
    field(:medium, :integer)
    field(:description, :string)

    field(:streamed, :boolean)

    field(:operation_id, :string)
  end

  def create(params) do
    changeset(%__MODULE__{}, params) |> Audit.Repo.insert()
  end

  def all(params) do
    default = %{org_id: :skip, streamed: :skip, limit: :skip}
    params = Map.merge(default, params)

    __MODULE__
    |> filter_by_org_id(params.org_id)
    |> filter_by_streamed(params.streamed)
    |> limit_size(params.limit)
    |> order_by(asc: :timestamp)
    |> Audit.Repo.all()
  end

  defp filter_by_org_id(query, :skip), do: query

  defp filter_by_org_id(query, org_id),
    do: query |> where([e], e.org_id == ^org_id)

  defp filter_by_streamed(query, :skip), do: query
  defp filter_by_streamed(query, streamed), do: query |> where([e], e.streamed == ^streamed)

  defp limit_size(query, :skip), do: query
  defp limit_size(query, size), do: query |> limit(^size)

  def paginated(params, options) do
    default = %{org_id: :skip}
    default_opts = %{direction: :NEXT, page_token: "", page_size: 20}

    params = Map.merge(default, params)
    options = Map.merge(default_opts, options)

    %{entries: events, metadata: %{after: next_token, before: prev_token}} =
      __MODULE__
      |> filter_by_org_id(params.org_id)
      |> order_by([e], desc: e.timestamp)
      |> Audit.Repo.paginate(page_opts(options.direction, options.page_token, options.page_size))

    {events, next_token, prev_token}
  end

  defp page_opts(_direction, "", page_size) do
    [
      limit: page_size,
      cursor_fields: [{:timestamp, :desc}, {:operation_id, :desc}]
    ]
  end

  defp page_opts(:NEXT, page_token, page_size) do
    [after: page_token] ++ page_opts(nil, "", page_size)
  end

  defp page_opts(:PREVIOUS, page_token, page_size) do
    [before: page_token] ++ page_opts(nil, "", page_size)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :resource,
      :operation,
      :timestamp,
      :org_id,
      :user_id,
      :operation_id,
      :ip_address,
      :username,
      :resource_id,
      :resource_name,
      :metadata,
      :description,
      :medium
    ])
  end
end
