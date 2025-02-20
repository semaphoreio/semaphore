defmodule Front.Models.DeploymentsError do
  defexception [:message]
end

defmodule Front.Models.Deployments do
  @moduledoc """
  Deployment Target API and models
  """

  defmodule Targets do
    alias Front.Models.DeploymentTarget, as: Target
    alias InternalApi.Gofer.DeploymentTargets, as: API

    def list(project_id, requester_id \\ "") do
      API.ListRequest
      |> Util.Proto.deep_new!(
        project_id: project_id,
        requester_id: requester_id
      )
      |> grpc_send()
    end

    def describe(target_id) do
      API.DescribeRequest
      |> Util.Proto.deep_new!(target_id: target_id)
      |> grpc_send()
    end

    def history(history_params) do
      API.HistoryRequest
      |> Util.Proto.deep_new!(history_params)
      |> grpc_send()
    end

    def cordon(target_id, cordoned?) do
      API.CordonRequest
      |> Util.Proto.deep_new!(
        target_id: target_id,
        cordoned: cordoned?
      )
      |> grpc_send()
    end

    def create(target_params, :no_changes, unique_token, requester_id) do
      API.CreateRequest
      |> Util.Proto.deep_new!(
        target: target_params,
        unique_token: unique_token,
        requester_id: requester_id
      )
      |> grpc_send()
    end

    def create(target_params, secret_params, unique_token, requester_id) do
      API.CreateRequest
      |> Util.Proto.deep_new!(
        target: target_params,
        secret: secret_params,
        unique_token: unique_token,
        requester_id: requester_id
      )
      |> grpc_send()
    end

    def update(target_params, :no_changes, unique_token, requester_id) do
      API.UpdateRequest
      |> Util.Proto.deep_new!(
        target: target_params,
        unique_token: unique_token,
        requester_id: requester_id
      )
      |> grpc_send()
    end

    def update(target_params, secret_params, unique_token, requester_id) do
      API.UpdateRequest
      |> Util.Proto.deep_new!(
        target: target_params,
        secret: secret_params,
        unique_token: unique_token,
        requester_id: requester_id
      )
      |> grpc_send()
    end

    def delete(target_id, unique_token, requester_id) do
      API.DeleteRequest
      |> Util.Proto.deep_new!(
        target_id: target_id,
        unique_token: unique_token,
        requester_id: requester_id
      )
      |> grpc_send()
    end

    defp grpc_send(request) do
      endpoint = Application.fetch_env!(:front, :gofer_grpc_endpoint)

      case Front.Models.Deployments.send(endpoint, request_to_func(request), request) do
        {:ok, %{targets: targets}} -> {:ok, targets}
        {:ok, %{target: target}} -> {:ok, target}
        {:ok, %{target_id: target_id}} -> {:ok, target_id}
        {:ok, payload} when is_map(payload) -> {:ok, payload}
        {:error, reason} -> {:error, reason}
      end
    end

    defp request_to_func(%API.ListRequest{}), do: &API.DeploymentTargets.Stub.list/2
    defp request_to_func(%API.DescribeRequest{}), do: &API.DeploymentTargets.Stub.describe/2
    defp request_to_func(%API.HistoryRequest{}), do: &API.DeploymentTargets.Stub.history/2
    defp request_to_func(%API.CordonRequest{}), do: &API.DeploymentTargets.Stub.cordon/2
    defp request_to_func(%API.CreateRequest{}), do: &API.DeploymentTargets.Stub.create/2
    defp request_to_func(%API.UpdateRequest{}), do: &API.DeploymentTargets.Stub.update/2
    defp request_to_func(%API.DeleteRequest{}), do: &API.DeploymentTargets.Stub.delete/2
  end

  defmodule Secrets do
    alias Front.Models.DeploymentTarget, as: Target
    alias InternalApi.Secrethub, as: API
    require Logger

    def encrypt_data(:no_changes), do: {:ok, :no_changes}

    def encrypt_data(secret_data) do
      encoded_payload =
        secret_data
        |> Map.take(~w(env_vars files)a)
        |> Util.Proto.deep_new!(API.Secret.Data)
        |> API.Secret.Data.encode()

      with {:ok, {key_id, public_key}} <- get_key(),
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
        {:error, %GRPC.RPCError{message: message}} ->
          Logger.error("#{__MODULE__}.get_key/0: #{message}")
          {:error, %Front.Models.DeploymentsError{message: "Cannot fetch key"}}

        {:error, %RuntimeError{message: message}} ->
          Logger.error("#{__MODULE__}.get_key/0: #{message}")
          {:error, %Front.Models.DeploymentsError{message: "Invalid public key"}}

        {:error, reason} ->
          Logger.error("#{__MODULE__}.encrypt_data/2: #{inspect(reason)}")
          {:error, %Front.Models.DeploymentsError{message: "Encryption failed"}}

        {:error, reason, _stacktrace} ->
          Logger.error("#{__MODULE__}.encrypt_data/2: #{inspect(reason)}")
          {:error, %Front.Models.DeploymentsError{message: "Encryption failed"}}
      end
    end

    def describe_data(target_id, meta_args) do
      request =
        API.DescribeRequest
        |> Util.Proto.deep_new!(%{
          metadata: meta_args,
          secret_level: :DEPLOYMENT_TARGET,
          deployment_target_id: target_id
        })

      func = &API.SecretService.Stub.describe/2

      case do_send(func, request) do
        {:ok, %{metadata: %{status: %{code: :OK}}, secret: secret}} ->
          {:ok, secret.data}

        {:ok, %{metadata: %{status: %{code: :NOT_FOUND, message: _message}}}} ->
          {:ok, %{env_vars: [], files: []}}

        {:ok, %{metadata: %{status: %{code: :FAILED_PRECONDITION, message: message}}}} ->
          {:error, grpc_error(:failed_precondition, message)}

        {:error, reason} ->
          {:error, reason}
      end
    end

    def get_key do
      request = API.GetKeyRequest.new()
      func = &API.SecretService.Stub.get_key/2
      decode_der = &ExPublicKey.RSAPublicKey.decode_der/1

      with {:ok, %{id: id, key: raw_key}} <- do_send(func, request),
           {:ok, base_decoded_key} <- Base.decode64(raw_key),
           {:ok, rsa_public_key} <- decode_der.(base_decoded_key) do
        {:ok, {id, rsa_public_key}}
      else
        :error -> {:error, %RuntimeError{message: "Base64 decode for key failed"}}
        error -> error
      end
    end

    defp do_send(func, request) do
      endpoint = Application.fetch_env!(:front, :secrets_api_grpc_endpoint)
      Front.Models.Deployments.send(endpoint, func, request)
    end

    defp grpc_error(status, message) do
      status_code = apply(GRPC.Status, status, [])
      GRPC.RPCError.exception(status: status_code, message: message)
    end
  end

  alias Front.Models.DeploymentTarget, as: Target
  require Logger

  def fetch_targets(project_id, requester_id \\ "") do
    if Application.get_env(:front, :hide_promotions, false) do
      {:ok, []}
    else
      Targets.list(project_id, requester_id)
    end
  end

  def fetch_target(target_id) do
    Targets.describe(target_id)
  end

  def fetch_history(target_id, opts \\ []) do
    Targets.history(
      target_id: target_id,
      cursor_type: Keyword.get(opts, :direction, :FIRST),
      cursor_value: Keyword.get(opts, :timestamp, 0),
      filters: Keyword.get(opts, :filters, %{}),
      requester_id: Keyword.get(opts, :requester_id, "")
    )
  end

  def fetch_secret_data(target_id, meta_args) do
    Secrets.describe_data(target_id, meta_args)
  end

  def create(params, extra_args) do
    with {:ok, changeset = %Ecto.Changeset{valid?: true}} <- Target.validate(params),
         {:ok, secret_data} <- Target.extract_secret_data(changeset),
         {:ok, secret_params} <- Secrets.encrypt_data(secret_data) do
      new_model = Ecto.Changeset.apply_changes(changeset)
      target_params = Target.to_api(new_model, extra_args)
      unique_token = Map.get(new_model, :unique_token)
      requester_id = Map.get(extra_args, :requester_id)

      Targets.create(target_params, secret_params, unique_token, requester_id)
    end
  end

  def update(model, params, secret_data, extra_args) do
    with {:ok, changeset = %Ecto.Changeset{valid?: true}} <- Target.validate(model, params),
         {:ok, secret_data} <- Target.extract_secret_data(changeset, secret_data),
         {:ok, secret_params} <- Secrets.encrypt_data(secret_data) do
      new_model = Ecto.Changeset.apply_changes(changeset)
      target_params = Target.to_api(new_model, extra_args)
      unique_token = Map.get(new_model, :unique_token)
      requester_id = Map.get(extra_args, :requester_id)

      Targets.update(target_params, secret_params, unique_token, requester_id)
    end
  end

  def switch_cordon(target_id, :on),
    do: Targets.cordon(target_id, true)

  def switch_cordon(target_id, :off),
    do: Targets.cordon(target_id, false)

  def delete(target_id, extra_args) do
    Targets.delete(target_id, UUID.uuid4(), extra_args[:requester_id])
  end

  # gRPC client

  def send(endpoint, func, request) do
    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- grpc_send(channel, func, request) do
      Util.Proto.to_map(response)
    else
      {:error, _reason} = error -> error
    end
  end

  defp grpc_send(channel, func, request),
    do: func.(channel, request),
    after: GRPC.Stub.disconnect(channel)
end
