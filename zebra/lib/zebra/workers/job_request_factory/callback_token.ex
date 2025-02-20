defmodule Zebra.Workers.JobRequestFactory.CallbackToken do
  require Logger

  defmodule Token do
    use Joken.Config, default_key: :hs256

    @impl true
    def token_config do
      default_claims(skip: [:iss, :aud])
    end
  end

  @algo "HS256"

  # The token expires after 24h
  @expire_in 60 * 60 * 24

  def generate(job) do
    if Zebra.Models.Job.self_hosted?(job.machine_type) do
      {:ok, ""}
    else
      key = active_key()
      signer = Joken.Signer.create(@algo, key)

      case __MODULE__.Token.generate_and_sign(claims(job), signer) do
        {:ok, token, _claims} ->
          {:ok, token}

        e ->
          Logger.error("Error generating callback token for #{job.id}: #{inspect(e)}")
          e
      end
    end
  end

  def claims(job) do
    %{
      "sub" => job.id,
      "jti" => Joken.generate_jti(),
      "iat" => Joken.current_time(),
      "nbf" => Joken.current_time(),
      "exp" => Joken.current_time() + @expire_in
    }
  end

  # We need to support several keys at the same time,
  # to facilitate the rotation process, so keys are kept in a comma-separated list.
  # The active key will always be the first in the list.
  # NOTE: we use HS256, so we need to use keys that are 32 bytes long, at least.
  def active_key do
    System.get_env("ZEBRA_CALLBACK_TOKEN_KEYS")
    |> String.split(",")
    |> List.first()
  end
end
