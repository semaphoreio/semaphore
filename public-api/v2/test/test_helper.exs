Support.Stubs.init()
Support.Stubs.Feature.seed()

formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end

ExUnit.configure(
  trace: true,
  capture_log: true,
  formatters: formatters
)

ExUnit.start()

defmodule Test.PipelinesClient do
  use ExUnit.Case

  def url, do: "localhost:4004"

  def headers(%{org_id: org_id, user_id: user_id}),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", org_id}
    ]

  def post_partial_rebuild(ppl_id, ctx, args, expected_status_code, decode? \\ true)
      when is_map(args) do
    {:ok, response} =
      args
      |> Jason.encode!()
      |> post_partial_rebuild_request(ctx, ppl_id)

    %{:body => body, :status_code => status_code} = response

    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))

    assert status_code == expected_status_code

    case decode? do
      true -> Jason.decode!(body)
      false -> body
    end
  end

  def post_reschedule(wf_id, ctx, args, expected_status_code, decode? \\ true)
      when is_map(args) do
    {:ok, response} =
      args
      |> Jason.encode!()
      |> post_reschedule_request(ctx, wf_id)

    %{:body => body, :status_code => status_code} = response

    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))

    assert status_code == expected_status_code

    case decode? do
      true -> Jason.decode!(body)
      false -> body
    end
  end

  def describe_ppl_with_id(id, ctx, decode? \\ true, detailed \\ false) do
    {:ok, response} = get_ppl_description(id, ctx, Atom.to_string(detailed))
    %{:body => body, :status_code => status_code} = response
    if(status_code != 200, do: IO.puts("Response body: #{inspect(body)}"))

    body =
      case decode? do
        true -> Jason.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  def describe_wf(wf_id, ctx, decode? \\ true) do
    {:ok, response} = get_wf_description(wf_id, ctx)
    %{:body => body, :status_code => status_code} = response
    if(status_code != 200, do: IO.puts("Response body: #{inspect(body)}"))

    body =
      case decode? do
        true -> Jason.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp get_wf_description(wf_id, ctx),
    do: HTTPoison.get(url() <> "/workflows/" <> wf_id, headers(ctx))

  defp post_partial_rebuild_request(body, ctx, ppl_id) do
    HTTPoison.post(url() <> "/pipelines/" <> ppl_id <> "/partial_rebuild", body, headers(ctx))
  end

  defp post_reschedule_request(body, ctx, wf_id) do
    HTTPoison.post(url() <> "/workflows/" <> wf_id <> "/reschedule", body, headers(ctx))
  end

  defp get_ppl_description(id, ctx, detailed),
    do:
      HTTPoison.get(url() <> "/pipelines/" <> id <> "?detailed=" <> detailed, headers(ctx),
        timeout: 100_000,
        recv_timeout: 1_000_000
      )

  def headers_contain(list, headers) do
    Enum.map(list, fn value ->
      unless Enum.find(headers, nil, match_headers(value)) != nil do
        assert false
      end
    end)
  end

  def match_headers({"link", expected_links}) do
    parsed =
      parse_link_header(expected_links)
      |> decode_query_params()

    fn
      {"link", links} ->
        parsed_link = parse_link_header(links) |> decode_query_params()
        same? = parsed == parsed_link

        if not same? do
          require Logger

          Logger.error(
            "Expected header: #{inspect(parsed)}, instead got: #{inspect(parsed_link)}"
          )
        end

        same?

      _ ->
        false
    end
  end

  def match_headers(a), do: fn x -> x == a end

  defp decode_query_params(list) do
    Enum.map(list, fn %{url: url} -> URI.decode_query(url) end)
  end

  def parse_link_header(header) do
    # Split the header into individual links
    links = String.split(header, ",")

    Enum.map(links, fn link ->
      # Use regex to extract the URL and rel from each link
      [_, url, rel] = Regex.run(~r/<([^>]+)>; rel="([^"]+)"/, link)
      # url contains encodings, so we need to decode it (eg. %2F -> /)
      url = URI.decode(url)
      %{url: url, rel: rel}
    end)
  end
end

defmodule PublicAPI.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Test.PipelinesClient, only: [url: 0, headers: 1]
      alias Support.Stubs.PermissionPatrol
    end
  end
end
