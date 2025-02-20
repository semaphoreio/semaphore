defmodule PublicAPI.Handlers.DeploymentTargets.Util.Encrypt do
  @moduledoc """
  Utility module for encrypting secret data.
  """
  alias PublicAPI.Util.ToTuple
  alias InternalApi.Secrethub.Secret

  def encrypt_data(secret_data, key) do
    with secret_data_filtered <- secret_data |> Map.take(~w(env_vars files)a),
         secret_data_grpc <- %Secret.Data{
           env_vars:
             Map.get(secret_data_filtered, :env_vars, [])
             |> Enum.map(&%Secret.EnvVar{name: &1.name, value: &1.value}),
           files:
             Map.get(secret_data_filtered, :files, [])
             |> Enum.map(&%Secret.File{path: &1.path, content: &1.content})
         },
         encoded_payload <-
           secret_data_grpc
           |> Secret.Data.encode(),
         {:ok, {key_id, public_key}} <- key,
         {:ok, aes256_key} <-
           ExCrypto.generate_aes_key(:aes_256, :bytes),
         {:ok, {init_vector, encrypted_payload}} <-
           ExCrypto.encrypt(aes256_key, encoded_payload),
         {:ok, encrypted_aes256_key} <-
           ExPublicKey.encrypt_public(aes256_key, public_key),
         {:ok, encrypted_init_vector} <-
           ExPublicKey.encrypt_public(init_vector, public_key) do
      {:ok,
       %{
         key_id: to_string(key_id),
         aes256_key: to_string(encrypted_aes256_key),
         init_vector: to_string(encrypted_init_vector),
         payload: Base.encode64(encrypted_payload)
       }}
    else
      {:error, %RuntimeError{message: _}} ->
        "Invalid public key" |> ToTuple.error()

      {:error, _} ->
        "Encryption failed" |> ToTuple.error()

      {:error, _, _stacktrace} ->
        "Encryption failed" |> ToTuple.error()

      _ ->
        {:error, {:internal, "internal error"}}
    end
  end
end
