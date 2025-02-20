defmodule E2E.Clients.Common do
  @user_agent "SemaphoreCI v2.0 Client"

  def base_domain, do: Application.fetch_env!(:e2e, :semaphore_base_domain)
  def organization, do: Application.fetch_env!(:e2e, :semaphore_organization)

  def api_base_url, do: "https://#{organization()}.#{base_domain()}"

  def api_url(endpoint \\ ""), do: "#{api_base_url()}/#{endpoint}"

  def get_headers(), do: _get_headers(Application.fetch_env!(:e2e, :semaphore_api_token))
  def get_headers(api_token), do: _get_headers(api_token)

  def _get_headers(api_token) do
    [
      {"Authorization", "Token #{api_token}"},
      {"User-Agent", @user_agent},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

  def post(endpoint, body \\ %{}) do
    headers = get_headers()
    body = Jason.encode!(body)
    url = api_url(endpoint)
    timeout = Application.get_env(:e2e, :http_timeout, 30_000)

    case HTTPoison.post(url, body, headers, timeout: timeout, recv_timeout: timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        # Retry once on timeout
        Process.sleep(1000)
        HTTPoison.post(url, body, headers, timeout: timeout, recv_timeout: timeout)

      error ->
        error
    end
  end

  def get(endpoint) do
    headers = get_headers()
    url = api_url(endpoint)
    timeout = Application.get_env(:e2e, :http_timeout, 30_000)

    case HTTPoison.get(url, headers, timeout: timeout, recv_timeout: timeout, follow_redirect: true) do
      {:ok, response} ->
        {:ok, response}

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        # Retry once on timeout
        Process.sleep(1000)
        HTTPoison.get(url, headers, timeout: timeout, recv_timeout: timeout, follow_redirect: true)

      error ->
        error
    end
  end

  def put(endpoint, body \\ %{}) do
    headers = get_headers()
    url = api_url(endpoint)
    body = Jason.encode!(body)
    timeout = Application.get_env(:e2e, :http_timeout, 30_000)

    case HTTPoison.put(url, body, headers, timeout: timeout, recv_timeout: timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        # Retry once on timeout
        Process.sleep(1000)
        HTTPoison.put(url, body, headers, timeout: timeout, recv_timeout: timeout)

      error ->
        error
    end
  end

  def patch(endpoint, body \\ %{}) do
    headers = get_headers()
    url = api_url(endpoint)
    body = Jason.encode!(body)
    timeout = Application.get_env(:e2e, :http_timeout, 30_000)

    case HTTPoison.patch(url, body, headers, timeout: timeout, recv_timeout: timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        # Retry once on timeout
        Process.sleep(1000)
        HTTPoison.patch(url, body, headers, timeout: timeout, recv_timeout: timeout)

      error ->
        error
    end
  end

  def delete(endpoint) do
    headers = get_headers()
    url = api_url(endpoint)
    timeout = Application.get_env(:e2e, :http_timeout, 30_000)

    case HTTPoison.delete(url, headers, timeout: timeout, recv_timeout: timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        # Retry once on timeout
        Process.sleep(1000)
        HTTPoison.delete(url, headers, timeout: timeout, recv_timeout: timeout)

      error ->
        error
    end
  end
end
