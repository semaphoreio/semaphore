defmodule PipelinesAPI.Deployments.Common do
  @moduledoc """
  Utility functions needed to handle deployment targets operations, like getting project ID
  from the connection, process response, encode data, etc.
  """

  use Plug.Builder

  alias PipelinesAPI.DeploymentsClient
  alias PipelinesAPI.Pipelines.Common
  alias Util.ToTuple
  alias Plug.Conn

  @sensitive_param_fields ~w(key old_env_vars old_files old_target)
  @plans_docs_link "https://semaphoreci.com/pricing"

  def get_project_id_from_target(conn, _opts) do
    case retrieve_project_id(conn, conn.params) do
      {:ok, project_id} ->
        Conn.assign(conn, :project_id, project_id)

      {:error, {:not_found, _message}} = error ->
        error |> Common.respond(conn) |> halt()

      {:error, error} ->
        error |> Common.respond(conn) |> halt()
    end
  end

  def get_project_id_from_params(conn, _opts) do
    Conn.assign(conn, :project_id, conn.params["project_id"])
  end

  defp retrieve_project_id(conn, %{"target_id" => target_id}),
    do: retrieve_project_id(conn, target_id)

  defp retrieve_project_id(conn, %{"id" => target_id}), do: retrieve_project_id(conn, target_id)

  defp retrieve_project_id(conn, target_id)
       when is_binary(target_id) and byte_size(target_id) > 0 do
    DeploymentsClient.describe(%{"target_id" => target_id})
    |> process_response(conn)
  end

  defp process_response({:ok, target}, conn), do: {:ok, target.project_id}

  defp process_response(error, _conn), do: {:error, error}

  def encrypt_data(secret_data, key) do
    with secret_data_filtered <- secret_data |> Map.take(~w(env_vars files)a),
         {:ok, secret_data_grpc} <-
           secret_data_filtered |> Util.Proto.deep_new(InternalApi.Secrethub.Secret.Data),
         encoded_payload <- secret_data_grpc |> InternalApi.Secrethub.Secret.Data.encode(),
         {key_id, public_key} <- key,
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

  def has_deployment_targets_enabled(conn = %{params: %{"subject_rules" => nil}}, opts),
    do: has_feature_enabled(conn, opts, :deployment_targets)

  def has_deployment_targets_enabled(
        conn = %{params: %{"subject_rules" => [%{"type" => "ANY"}]}},
        opts
      ),
      do: has_feature_enabled(conn, opts, :deployment_targets)

  def has_deployment_targets_enabled(conn = %{params: %{"subject_rules" => subject_rules}}, opts)
      when is_list(subject_rules),
      do: has_feature_enabled(conn, opts, :advanced_deployment_targets)

  def has_deployment_targets_enabled(conn, opts),
    do: has_feature_enabled(conn, opts, :deployment_targets)

  defp has_feature_enabled(conn, _opts, feature) do
    with org_id <- Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0),
         true <- FeatureProvider.feature_enabled?(feature, param: org_id) do
      conn
    else
      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> resp(
          403,
          "The #{feature_name(feature)} feature is not enabled for your organization. See more details here: #{@plans_docs_link}"
        )
        |> halt
    end
  end

  defp feature_name(feature), do: feature |> to_string |> String.replace("_", " ")

  def remove_sensitive_params(conn = %{params: params}, _opts) do
    conn |> Map.put(:params, params |> Map.drop(@sensitive_param_fields))
  end

  def is_list_of_subject_rules(nil), do: true

  def is_list_of_subject_rules(subject_rules) when is_list(subject_rules) do
    Enum.all?(subject_rules, &is_map_of_subject_rule/1)
  end

  def is_list_of_subject_rules(_), do: false

  defp is_map_of_subject_rule(subject_rule) when is_map(subject_rule) do
    Map.has_key?(subject_rule, "type")
  end

  defp is_map_of_subject_rule(_), do: false

  def is_list_of_object_rules(nil), do: true

  def is_list_of_object_rules(object_rules) when is_list(object_rules) do
    Enum.all?(object_rules, &is_map_of_object_rule/1)
  end

  def is_list_of_object_rules(_), do: false

  defp is_map_of_object_rule(object_rule) when is_map(object_rule) do
    Map.has_key?(object_rule, "type") and
      Map.has_key?(object_rule, "match_mode") and
      Map.has_key?(object_rule, "pattern")
  end

  defp is_map_of_object_rule(_), do: false
end
