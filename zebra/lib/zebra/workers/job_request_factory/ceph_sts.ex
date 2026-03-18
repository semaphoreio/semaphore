defmodule Zebra.Workers.JobRequestFactory.CephSts do
  @moduledoc false

  @retry_attempts 3
  @retry_backoff_ms 250

  def assume_role(role_arn, session_name, duration_seconds) do
    with {:ok, config} <- load_config() do
      params = %{
        "Action" => "AssumeRole",
        "Version" => "2011-06-15",
        "RoleArn" => role_arn,
        "RoleSessionName" => session_name,
        "DurationSeconds" => Integer.to_string(duration_seconds)
      }

      body = URI.encode_query(params)
      url = "#{config.endpoint}/"
      headers = [{"content-type", "application/x-www-form-urlencoded; charset=utf-8"}]

      with {:ok, %{body: response_body}} <-
             request_with_retry(config, :post, url, credentials(config), headers, body) do
        case xml_tag(response_body, "Code") do
          "" ->
            access_key_id = xml_tag(response_body, "AccessKeyId")
            secret_access_key = xml_tag(response_body, "SecretAccessKey")
            session_token = xml_tag(response_body, "SessionToken")

            if access_key_id != "" and secret_access_key != "" and session_token != "" do
              {:ok,
               %{
                 access_key_id: access_key_id,
                 secret_access_key: secret_access_key,
                 session_token: session_token
               }}
            else
              {:error, :invalid_sts_response}
            end

          code ->
            {:error, {:sts_error, code, xml_tag(response_body, "Message")}}
        end
      end
    end
  end

  defp load_config do
    endpoint = System.get_env("CEPH_ENDPOINT")
    access_key = System.get_env("CEPH_ZEBRA_ACCESS_KEY")
    secret_key = System.get_env("CEPH_ZEBRA_SECRET_KEY")

    missing =
      [
        {"CEPH_ENDPOINT", endpoint},
        {"CEPH_ZEBRA_ACCESS_KEY", access_key},
        {"CEPH_ZEBRA_SECRET_KEY", secret_key}
      ]
      |> Enum.filter(fn {_name, value} -> blank?(value) end)
      |> Enum.map(&elem(&1, 0))

    if missing == [] do
      {:ok,
       %{
         endpoint: String.trim_trailing(endpoint, "/"),
         region: System.get_env("CEPH_REGION") || "us-east-1",
         request_timeout_ms: parse_int(System.get_env("CEPH_REQUEST_TIMEOUT_MS"), 15_000),
         insecure_skip_verify?: parse_bool(System.get_env("CEPH_INSECURE_SKIP_VERIFY"), false),
         access_key: access_key,
         secret_key: secret_key
       }}
    else
      {:error, {:missing_config, missing}}
    end
  end

  defp request_with_retry(config, method, url, creds, headers, body) do
    do_request_with_retry(config, method, url, creds, headers, body, @retry_attempts)
  end

  defp do_request_with_retry(config, method, url, creds, headers, body, attempts_left) do
    case signed_http_request(config, method, url, creds, headers, body) do
      {:ok, %{status: status}}
      when status in [408, 429, 500, 502, 503, 504] and attempts_left > 1 ->
        :timer.sleep(backoff_ms(attempts_left))
        do_request_with_retry(config, method, url, creds, headers, body, attempts_left - 1)

      {:error, _reason} when attempts_left > 1 ->
        :timer.sleep(backoff_ms(attempts_left))
        do_request_with_retry(config, method, url, creds, headers, body, attempts_left - 1)

      other ->
        other
    end
  end

  defp signed_http_request(config, method, url, creds, headers, body) do
    headers = maybe_add_host_header(headers, url)

    signing_input = %{
      access_key: creds.access_key,
      secret_key: creds.secret_key,
      region: config.region,
      service: "sts",
      request_datetime: :calendar.universal_time(),
      request_method: method |> to_string() |> String.upcase(),
      request_url: url,
      request_headers: normalize_signing_headers(headers),
      request_body: body
    }

    case sign_v4(signer_module(), signing_input) do
      signed_headers when is_list(signed_headers) ->
        do_http_request(config, method, url, signed_headers, body)

      {:ok, signed_headers} when is_list(signed_headers) ->
        do_http_request(config, method, url, signed_headers, body)

      {:error, reason} ->
        {:error, {:signing_error, reason}}

      other ->
        {:error, {:invalid_signing_response, other}}
    end
  rescue
    error ->
      {:error, {:signing_error, error}}
  end

  defp sign_v4(module, input) do
    cond do
      function_exported?(module, :sign_v4, 1) ->
        module.sign_v4(input)

      function_exported?(module, :sign_v4, 9) ->
        module.sign_v4(
          input.access_key,
          input.secret_key,
          input.region,
          input.service,
          input.request_datetime,
          input.request_method,
          input.request_url,
          input.request_headers,
          input.request_body
        )

      true ->
        {:error, {:unsupported_signer_module, module}}
    end
  end

  defp do_http_request(config, method, url, headers, body) do
    request =
      {String.to_charlist(url), to_httpc_headers(headers), 'application/x-www-form-urlencoded',
       body}

    case http_client_module().request(method, request, http_options(config), [body_format: :binary]) do
      {:ok, {{_http_version, status, _reason_phrase}, _response_headers, response_body}} ->
        {:ok, %{status: status, body: response_body}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp http_options(config) do
    ssl =
      if config.insecure_skip_verify? do
        [verify: :verify_none]
      else
        [verify: :verify_peer]
      end

    [
      timeout: config.request_timeout_ms,
      connect_timeout: config.request_timeout_ms,
      ssl: ssl
    ]
  end

  defp to_httpc_headers(headers) do
    Enum.map(headers, fn {name, value} ->
      {to_charlist(to_string(name)), to_charlist(to_string(value))}
    end)
  end

  defp normalize_signing_headers(headers) do
    Enum.map(headers, fn {name, value} ->
      {to_string(name), to_string(value)}
    end)
  end

  defp maybe_add_host_header(headers, url) do
    if Enum.any?(headers, fn {name, _} -> String.downcase(to_string(name)) == "host" end) do
      headers
    else
      host =
        case URI.parse(url) do
          %URI{host: host, port: nil} when is_binary(host) ->
            host

          %URI{host: host, port: port} when is_binary(host) and is_integer(port) ->
            "#{host}:#{port}"

          _ ->
            ""
        end

      [{"host", host} | headers]
    end
  end

  defp xml_tag(xml, tag) do
    {doc, _rest} = :xmerl_scan.string(String.to_charlist(xml))
    xpath = "string(//*[local-name()='#{tag}'][1])" |> String.to_charlist()

    case :xmerl_xpath.string(xpath, doc) do
      value when is_list(value) -> to_string(value)
      {:xmlObj, :string, value} when is_list(value) -> to_string(value)
      _ -> ""
    end
  rescue
    _ -> ""
  end

  defp parse_int(nil, default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _} -> parsed
      :error -> default
    end
  end

  defp parse_bool(nil, default), do: default

  defp parse_bool(value, _default) when is_binary(value) do
    String.downcase(value) in ["1", "true", "yes", "y", "on"]
  end

  defp backoff_ms(attempts_left) do
    @retry_backoff_ms * trunc(:math.pow(2, @retry_attempts - attempts_left))
  end

  defp credentials(config), do: %{access_key: config.access_key, secret_key: config.secret_key}

  defp signer_module do
    Application.get_env(:zebra, :ceph_sts_signer_module, :aws_signature)
  end

  defp http_client_module do
    Application.get_env(:zebra, :ceph_sts_http_client_module, :httpc)
  end

  defp blank?(value), do: value in [nil, "", " "]
end
