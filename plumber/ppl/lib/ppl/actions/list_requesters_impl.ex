defmodule Ppl.Actions.ListRequestersImpl do
  @moduledoc """
  Module which implements ListRequesters  action
  """

  import Ecto.Query

  alias InternalApi.Plumber.{
    ListRequestersRequest,
    ListRequestersResponse,
    Requester
  }

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplRequests.Model.PplRequests

  @type list_request :: %{
          organization_id: String.t(),
          requested_at_gt: DateTime.t(),
          requested_at_lte: DateTime.t(),
          page: integer(),
          page_size: integer()
        }

  def list_requesters(request) do
    request
    |> to_list_request()
    |> case do
      {:ok, list_request} ->
        {:ok, list_requesters_sql(list_request)}

      {:error, error} ->
        {:error, error}
    end
    |> case do
      {:ok, {requesters, next_page_token}} ->
        response =
          ListRequestersResponse.new(
            requesters: requesters,
            next_page_token: next_page_token
          )

        {:ok, response}

      {:error, error} ->
        {:error, error}
    end
  rescue
    e ->
      {:error, e}
  end

  @spec to_list_request(ListRequestersRequest.t()) :: {:ok, list_request()} | {:error, any()}
  defp to_list_request(request = %{page_token: page_token}) when page_token != "" do
    decode_page_token(request.page_token)
  end

  defp to_list_request(request) do
    with {:ok, organization_id} <- fetch_organization_id(request),
         {:ok, requested_at_gt} <- fetch_requested_at_gt(request),
         {:ok, requested_at_lte} <- fetch_requested_at_lte(request),
         {:ok, page_size} <- fetch_page_size(request) do
      {:ok,
       %{
         organization_id: organization_id,
         requested_at_gt: requested_at_gt,
         requested_at_lte: requested_at_lte,
         page: 1,
         page_size: page_size
       }}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  @spec list_requesters_sql(list_request()) :: {entries :: list(), next_page_token :: String.t()}
  defp list_requesters_sql(list_request) do
    base_query()
    |> filter(list_request)
    # using subquery - otherwise we'll get our results in an unpredictable order
    |> subquery()
    |> order_by([ppl_req], asc: ppl_req.requested_at)
    |> Repo.paginate(page: list_request.page, page_size: list_request.page_size)
    |> case do
      %{entries: entries, total_pages: total_pages, page_number: page_number}
      when page_number >= total_pages ->
        {Enum.map(entries, &build_requester/1), ""}

      %{entries: entries, page_number: page_number} ->
        {Enum.map(entries, &build_requester/1),
         encode_page_token(%{list_request | page: page_number + 1})}
    end
  end

  defp filter(query, params) do
    params
    |> Enum.reduce(query, fn
      {:requested_at_gt, requested_at_gt}, query ->
        query
        |> where([ppl_req], ppl_req.inserted_at > ^requested_at_gt)

      {:requested_at_lte, requested_at_lte}, query ->
        query
        |> where([ppl_req], ppl_req.inserted_at <= ^requested_at_lte)

      {:organization_id, organization_id}, query ->
        query
        |> where(
          [ppl_req],
          fragment("? ->> 'organization_id' = ?", ppl_req.request_args, ^organization_id)
        )

      _condition, query ->
        query
    end)
  end

  defp base_query() do
    from(PplRequests)
    |> select([ppl_req], %{
      ppl_id:
        fragment(
          "distinct on (?, ?, ?, ?) ?",
          fragment("date_trunc('day', ?)", ppl_req.inserted_at),
          fragment("? ->> ?", ppl_req.request_args, "organization_id"),
          fragment("? ->> ?", ppl_req.source_args, "repo_host_username"),
          fragment("? ->> ?", ppl_req.request_args, "service"),
          ppl_req.id
        ),
      requested_at: ppl_req.inserted_at,
      organization_id: fragment("? ->> ?", ppl_req.request_args, "organization_id"),
      project_id: fragment("? ->> ?", ppl_req.request_args, "project_id"),
      user_id: fragment("? ->> ?", ppl_req.request_args, "requester_id"),
      triggerer: fragment("? ->> ?", ppl_req.request_args, "triggered_by"),
      provider_login: fragment("? ->> ?", ppl_req.source_args, "repo_host_username"),
      provider_uid: fragment("? ->> ?", ppl_req.source_args, "repo_host_user_id"),
      provider: fragment("? ->> ?", ppl_req.request_args, "service")
    })
    # Exclude scheduler requests
    |> where(
      [ppl_req],
      fragment("? ->> ? <> ?", ppl_req.request_args, "triggered_by", "schedule")
    )
    |> order_by(
      [ppl_req],
      [
        fragment("date_trunc('day', ?)", ppl_req.inserted_at),
        fragment("? ->> ?", ppl_req.request_args, "organization_id"),
        fragment("? ->> ?", ppl_req.source_args, "repo_host_username"),
        fragment("? ->> ?", ppl_req.request_args, "service")
      ]
    )
  end

  defp build_requester(requester) do
    requested_at_timestamp = Timex.to_unix(requester.requested_at)
    {:ok, ppl_id} = Ecto.UUID.cast(requester.ppl_id)

    %{
      organization_id: requester.organization_id,
      project_id: requester.project_id,
      ppl_id: ppl_id,
      user_id: requester.user_id || "",
      provider_login: requester.provider_login || "",
      provider_uid: requester.provider_uid || "",
      provider: parse_provider(requester.provider),
      triggerer: parse_triggerer(requester.triggerer),
      requested_at: Google.Protobuf.Timestamp.new(seconds: requested_at_timestamp)
    }
    |> Requester.new()
  end

  defp parse_triggerer(triggerer) do
    triggerer
    |> String.upcase()
    |> String.to_atom()
    |> InternalApi.PlumberWF.TriggeredBy.value()
  end

  defp parse_provider(provider) do
    case provider do
      "git_hub" ->
        :GITHUB

      value ->
        value
        |> String.upcase()
        |> String.to_atom()
    end
    |> InternalApi.User.RepositoryProvider.Type.value()
  end

  @spec decode_page_token(String.t()) :: {:ok, list_request} | {:error, any()}
  defp decode_page_token(token) do
    case Base.decode64(token) do
      {:ok, decoded} ->
        Poison.decode(decoded)

      :error ->
        {:error, {:BAD_PARAM, "Can't decode page token"}}
    end
    |> case do
      {:ok,
       %{
         "organization_id" => organization_id,
         "requested_at_gt" => requested_at_gt,
         "requested_at_lte" => requested_at_lte,
         "page" => page,
         "page_size" => page_size
       }} ->
        {:ok,
         %{
           organization_id: organization_id,
           requested_at_gt: requested_at_gt,
           requested_at_lte: requested_at_lte,
           page: page,
           page_size: page_size
         }}

      {:ok, _} ->
        {:error, {:BAD_PARAM, "Can't decode page token: #{inspect(token)}"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec encode_page_token(list_request()) :: String.t()
  def encode_page_token(%{
        organization_id: organization_id,
        requested_at_gt: requested_at_gt,
        requested_at_lte: requested_at_lte,
        page: page,
        page_size: page_size
      }) do
    token =
      Poison.encode!(%{
        organization_id: organization_id,
        requested_at_gt: requested_at_gt,
        requested_at_lte: requested_at_lte,
        page: page,
        page_size: page_size
      })

    Base.encode64(token)
  end

  defp fetch_organization_id(request) do
    if request.organization_id == "" do
      {:error, {:BAD_PARAM, "organization_id is required"}}
    else
      {:ok, request.organization_id}
    end
  end

  defp fetch_requested_at_gt(request) do
    if request.requested_at_gt == nil do
      {:error, {:BAD_PARAM, "requested_at_gt is required"}}
    else
      ts_to_datetime(request.requested_at_gt)
    end
  end

  defp fetch_requested_at_lte(request) do
    if request.requested_at_lte == nil do
      {:error, {:BAD_PARAM, "requested_at_lte is required"}}
    else
      ts_to_datetime(request.requested_at_lte)
    end
  end

  defp fetch_page_size(request) do
    request.page_size
    |> case do
      # default value
      page_size when page_size == 0 ->
        {:ok, 20}

      page_size when page_size >= 100 ->
        {:ok, 100}

      page_size when page_size < 0 ->
        {:ok, 1}

      page_size ->
        {:ok, page_size}
    end
  end

  defp ts_to_datetime(%{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    DateTime.from_unix(ts_in_microseconds, :microsecond)
  end
end
