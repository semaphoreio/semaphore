defmodule Audit.Streamer.Log do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "streamer_logs" do
    field(:org_id, :binary_id)
    field(:streamed_at, :utc_datetime)
    field(:errors, :string)
    field(:provider, :integer)

    field(:file_size, :integer)
    field(:file_name, :string)

    field(:first_event_timestamp, :utc_datetime)
    field(:last_event_timestamp, :utc_datetime)
  end

  def create(params) do
    changeset(%__MODULE__{}, params) |> Audit.Repo.insert()
  end

  def new(success_response, config, first_timestamp, last_timestamp, file_name) do
    new(success_response, %{
      org_id: config.org_id,
      streamed_at: Timex.now(),
      provider: InternalApi.Audit.StreamProvider.value(config.provider),
      file_name: file_name,
      first_event_timestamp: first_timestamp,
      last_event_timestamp: last_timestamp
    })
  end

  def new({:ok, file_size}, params) do
    Map.merge(params, %{file_size: file_size})
    |> create
  end

  def new({:error, {:http_error, _, _}}, params) do
    Map.merge(params, %{
      errors: "You might have not provided correct access key or you missconfigoured the provider"
    })
    |> create
  end

  def new({:error, %{body: msg}}, params) do
    Map.merge(params, %{errors: msg})
    |> create
  end

  def new({:error, err}, params) do
    Map.merge(params, %{errors: inspect(err)})
    |> create
  end

  def list(org_id, options \\ %{}) do
    default_opts = %{direction: :NEXT, page_token: "", page_size: 20}
    options = Map.merge(default_opts, options)

    %{entries: logs, metadata: %{after: next_token, before: prev_token}} =
      __MODULE__
      |> where([e], e.org_id == ^org_id)
      |> order_by([e], desc: [e.streamed_at])
      |> Audit.Repo.paginate(page_opts(options.direction, options.page_token, options.page_size))

    {logs, next_token, prev_token}
  end

  defp page_opts(_direction, "", page_size) do
    [
      limit: page_size,
      cursor_fields: [{:streamed_at, :desc}]
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
      :org_id,
      :streamed_at,
      :errors,
      :provider,
      :file_size,
      :file_name,
      :first_event_timestamp,
      :last_event_timestamp
    ])
  end
end
