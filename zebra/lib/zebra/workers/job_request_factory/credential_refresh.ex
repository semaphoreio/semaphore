defmodule Zebra.Workers.JobRequestFactory.CredentialRefresh do
  @moduledoc """
  The S3 cache and registry credentials last at most 12 hours, while a job
  can run for 24. Along with them, cachehub returns a refresh grant scoped to
  the job, which the job sends to cachehub's job API to get fresh ones.

  Only jobs that got credentials get a grant, so jobs of forked pull
  requests, which get none, cannot refresh any either.
  """

  alias Zebra.Workers.JobRequestFactory.JobRequest

  # Grants outlast the job's time limit by this much, for its wait in the queue.
  @margin_seconds 60 * 60
  @max_seconds 25 * 60 * 60

  @doc "How long the job's refresh grant should last."
  def validity(%{execution_time_limit: limit}) when is_integer(limit) and limit > 0,
    do: min(limit + @margin_seconds, @max_seconds)

  def validity(_job), do: @max_seconds

  @doc """
  `<prefix>_EXPIRES_AT` (unix seconds) for the credentials, plus
  `<prefix>_REFRESH_TOKEN` and `<prefix>_REFRESH_URL` when cachehub issued a
  grant and its job API URL is configured.
  """
  def env_vars(prefix, kind, credentials) when kind in [:s3, :registry] do
    expires_at =
      case credentials.expires_at do
        %{seconds: seconds} when is_integer(seconds) and seconds > 0 ->
          [JobRequest.env_var("#{prefix}_EXPIRES_AT", Integer.to_string(seconds))]

        _ ->
          []
      end

    expires_at ++ refresh(prefix, kind, credentials.refresh_token)
  end

  defp refresh(prefix, kind, token) when is_binary(token) and token != "" do
    case base_url() do
      nil ->
        []

      url ->
        [
          JobRequest.env_var("#{prefix}_REFRESH_TOKEN", token),
          JobRequest.env_var("#{prefix}_REFRESH_URL", "#{url}/api/v1/credentials/#{kind}")
        ]
    end
  end

  defp refresh(_prefix, _kind, _token), do: []

  defp base_url do
    with url when is_binary(url) <- Application.get_env(:zebra, :cachehub_job_api_url),
         "https://" <> host = url when host != "" <-
           url |> String.trim() |> String.trim_trailing("/") do
      url
    else
      _ -> nil
    end
  end
end
