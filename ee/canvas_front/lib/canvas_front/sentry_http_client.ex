defmodule CanvasFront.SentryFinchHTTPClient do
  @behaviour Sentry.HTTPClient

  @impl true
  def child_spec do
    Supervisor.child_spec({Finch, name: __MODULE__}, id: __MODULE__)
  end

  @impl true
  def post(url, headers, body) do
    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, __MODULE__) do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, status, headers, body}

      {:error, error} ->
        {:error, error}
    end
  end
end
