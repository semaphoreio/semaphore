Support.Stubs.init()

formatters = [PipelinesAPI.CustomExUnitFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end

ExUnit.configure(
  exclude: [integration: true, router: true, gofer_integration: true],
  formatters: formatters
)

ExUnit.start(trace: true, capture_log: true)

defmodule Test.PipelinesClient do
  use ExUnit.Case

  def url, do: "localhost:4004"

  def headers,
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()},
      {"x-semaphore-user-id", Support.Stubs.User.default_user_id()}
    ]

  def post_partial_rebuild(
        ppl_id,
        args,
        expected_status_code,
        decode? \\ true,
        headers \\ headers()
      )
      when is_map(args) do
    {:ok, response} =
      args
      |> Poison.encode!()
      |> post_partial_rebuild_request(ppl_id, headers)

    %{:body => body, :status_code => status_code} = response

    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))

    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  def post_reschedule(wf_id, args, expected_status_code, decode? \\ true, headers \\ headers())
      when is_map(args) do
    {:ok, response} =
      args
      |> Poison.encode!()
      |> post_reschedule_request(wf_id, headers)

    %{:body => body, :status_code => status_code} = response

    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))

    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  def describe_ppl_with_id(id, decode? \\ true, detailed \\ false, headers \\ headers()) do
    {:ok, response} = get_ppl_description(id, Atom.to_string(detailed), headers)
    %{:body => body, :status_code => status_code} = response

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  def describe_wf(wf_id, decode? \\ true, headers \\ headers()) do
    {:ok, response} = get_wf_description(wf_id, headers)
    %{:body => body, :status_code => status_code} = response

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp get_wf_description(wf_id, headers),
    do: HTTPoison.get(url() <> "/workflows/" <> wf_id, headers)

  defp post_partial_rebuild_request(body, ppl_id, headers) do
    HTTPoison.post(url() <> "/pipelines/" <> ppl_id <> "/partial_rebuild", body, headers)
  end

  defp post_reschedule_request(body, wf_id, headers) do
    HTTPoison.post(url() <> "/workflows/" <> wf_id <> "/reschedule", body, headers)
  end

  defp get_ppl_description(id, detailed, headers),
    do: HTTPoison.get(url() <> "/pipelines/" <> id <> "?detailed=" <> detailed, headers)
end
