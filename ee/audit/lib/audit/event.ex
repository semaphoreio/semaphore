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
    default = %{org_id: :skip, from_timestamp: nil, to_timestamp: nil}
    default_opts = %{direction: :NEXT, page_token: "", page_size: 20}

    params = Map.merge(default, params)
    options = Map.merge(default_opts, options)

    %{entries: events, metadata: %{after: next_token, before: prev_token}} =
      __MODULE__
      |> filter_by_org_id(params.org_id)
      |> filter_by_timestamp_from(params.from_timestamp)
      |> filter_by_timestamp_to(params.to_timestamp)
      |> bound_by_cursor_timestamp(options.direction, options.page_token)
      |> order_by([e], desc: e.timestamp, desc: e.operation_id, desc: e.id)
      |> Audit.Repo.paginate(
        page_opts(
          options.direction,
          upgrade_cursor(options.direction, options.page_token),
          options.page_size
        )
      )

    {events, next_token, prev_token}
  end

  # from_timestamp is inclusive, to_timestamp is exclusive.
  defp filter_by_timestamp_from(query, nil), do: query

  defp filter_by_timestamp_from(query, from),
    do: query |> where([e], e.timestamp >= ^from)

  defp filter_by_timestamp_to(query, nil), do: query

  defp filter_by_timestamp_to(query, to),
    do: query |> where([e], e.timestamp < ^to)

  # Paginator expresses the "after cursor" condition as
  #   (timestamp = t AND (operation_id, id) after the cursor) OR timestamp < t
  # which Postgres can't use as an index bound, so every page scans (and
  # discards) all newer rows of the org. That makes a full export quadratic.
  # The redundant "timestamp <= t" is implied by that condition, doesn't change
  # the result, and lets the (org_id, timestamp, ...) index start at the cursor.
  #
  # Only for NEXT: the PREVIOUS condition also matches NULL timestamps.
  # If the token can't be decoded, the bound is skipped and Paginator handles
  # the token exactly as before.
  defp bound_by_cursor_timestamp(query, :NEXT, page_token)
       when is_binary(page_token) and page_token != "" do
    case cursor_timestamp(page_token) do
      %DateTime{} = timestamp -> query |> where([e], e.timestamp <= ^timestamp)
      _ -> query
    end
  end

  defp bound_by_cursor_timestamp(query, _direction, _page_token), do: query

  # Tokens issued before id became a cursor field carry only timestamp and
  # operation_id, and Paginator raises on a missing last cursor field. Give
  # them an id that keeps every event sharing that timestamp and operation_id
  # in the requested page (at worst a few repeated rows, never lost ones).
  # PREVIOUS reverses the order, so there the widest id is the smallest one.
  @max_id 9_223_372_036_854_775_807

  defp upgrade_cursor(direction, page_token) when is_binary(page_token) and page_token != "" do
    case Paginator.Cursor.decode(page_token) do
      %{timestamp: _, operation_id: _} = cursor when not is_map_key(cursor, :id) ->
        id = if direction == :PREVIOUS, do: 0, else: @max_id
        cursor |> Map.put(:id, id) |> Paginator.Cursor.encode()

      _ ->
        page_token
    end
  rescue
    _ -> page_token
  end

  defp upgrade_cursor(_direction, page_token), do: page_token

  defp cursor_timestamp(page_token) do
    case Paginator.Cursor.decode(page_token) do
      %{timestamp: timestamp} -> timestamp
      [timestamp | _] -> timestamp
      _ -> nil
    end
  rescue
    _ -> nil
  end

  # The ORDER BY must match the cursor fields, and the cursor must be unique:
  # several events of one operation can share a timestamp and an operation_id,
  # so id is the final tie-breaker. Without it, rows at a page boundary are lost.
  defp page_opts(_direction, "", page_size) do
    [
      limit: page_size,
      cursor_fields: [{:timestamp, :desc}, {:operation_id, :desc}, {:id, :desc}]
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
