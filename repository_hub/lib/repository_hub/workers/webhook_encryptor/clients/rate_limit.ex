defmodule RepositoryHub.WebhookEncryptor.RateLimitError do
  @moduledoc """
  RateLimitError is a custom error module for handling rate limit errors.
  """
  defexception provider: nil, headers: nil, reset_at: nil, retry_after: nil

  @type t :: %__MODULE__{
          provider: nil | String.t(),
          headers: nil | [{String.t(), String.t()}],
          reset_at: nil | integer(),
          retry_after: nil | integer()
        }

  @default_wait_time 60

  @impl true
  def message(%__MODULE__{} = error) do
    to_multiline_string([
      "#{error.provider} API reached rate limit\n",
      "Rate limit headers from response:"
      | format_headers(error.headers)
    ])
  end

  @spec wait_time(t()) :: non_neg_integer()
  def wait_time(%__MODULE__{retry_after: retry_after})
      when not is_nil(retry_after) and retry_after > 0,
      do: retry_after

  def wait_time(%__MODULE__{reset_at: reset_at})
      when not is_nil(reset_at) and reset_at != 0 do
    now = DateTime.utc_now() |> DateTime.to_unix()
    if reset_at > now, do: reset_at - now, else: 0
  end

  def wait_time(_error), do: @default_wait_time

  defp format_headers(headers), do: Enum.into(headers, [], &format_header/1)
  defp format_header({key, value}), do: "- #{key}: #{value}"
  defp to_multiline_string(list), do: Enum.join(list, "\n")
end

defmodule RepositoryHub.WebhookEncryptor.RateLimit do
  @moduledoc """
  Tesla Middleware that handles rate limit errors from Bitbucket and Github APIs.
  """

  alias RepositoryHub.WebhookEncryptor.RateLimitError
  @behaviour Tesla.Middleware

  @impl true
  def call(%Tesla.Env{} = env, next, _opts) do
    case Tesla.run(env, next) do
      {:ok, %Tesla.Env{status: 403} = env} -> check_rate_limit(env)
      {:ok, %Tesla.Env{status: 429} = env} -> check_rate_limit(env)
      result -> result
    end
  end

  defp check_rate_limit(env) do
    cond do
      imply_by_remaining_header?(env) -> handle_rate_limit(env)
      imply_by_429_status?(env) -> handle_rate_limit(env)
      true -> {:ok, env}
    end
  end

  defp imply_by_remaining_header?(%Tesla.Env{} = env) do
    remaining_header = Tesla.get_header(env, "x-ratelimit-remaining")

    if remaining_header do
      case Integer.parse(remaining_header) do
        {0, _} -> true
        {_, _} -> false
      end
    else
      false
    end
  end

  defp imply_by_429_status?(%Tesla.Env{status: 429}), do: true
  defp imply_by_429_status?(%Tesla.Env{status: _status}), do: false

  defp handle_rate_limit(%Tesla.Env{headers: headers} = env) do
    x_ratelimit_headers =
      Enum.filter(headers, fn {key, _value} ->
        String.starts_with?(key, "x-ratelimit-")
      end)

    {:error,
     %RateLimitError{
       headers: x_ratelimit_headers,
       reset_at: get_integer_header(env, "x-ratelimit-reset"),
       retry_after: get_integer_header(env, "retry-after")
     }}
  end

  defp get_integer_header(%Tesla.Env{} = env, header) do
    value = Tesla.get_header(env, header)
    parsed = if is_binary(value), do: Integer.parse(value)
    if is_tuple(parsed), do: elem(parsed, 0), else: nil
  end
end
