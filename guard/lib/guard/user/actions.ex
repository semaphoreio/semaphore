defmodule Guard.User.Actions do
  alias Guard.User.SaltGenerator

  alias Guard.Repo
  alias Guard.FrontRepo

  require Logger

  @exchange_name "user_exchange"

  @type user_params :: Map.t()

  @spec create(user_params) ::
          {:ok, Repo.RbacUser.t()} | {:error, List.t()} | {:error, Atom.t()}
  def create(user_params) do
    {password, user_params} = Map.pop(user_params, :password)
    {oidc_user_id, user_params} = Map.pop(user_params, :oidc_user_id)
    {repository_providers, user_params} = Map.pop(user_params, :repository_providers)
    skip_password_change = Map.get(user_params, :skip_password_change, false)

    name = ensure_name(user_params.name, user_params.email)
    user_params = Map.put(user_params, :name, name)

    case _create(user_params, password, oidc_user_id, repository_providers, skip_password_change) do
      {:ok, user} ->
        Guard.Events.UserCreated.publish(user.id, false)

        {:ok, user}

      error ->
        error
    end
  end

  defp ensure_name(name, email) when is_nil(name) or name == "" do
    case String.split(email, "@") do
      [username | _] -> username
      _ -> nil
    end
  end

  defp ensure_name(name, _), do: name

  defp _create(params, password, oidc_user_id, repository_providers, skip_password_change) do
    FrontRepo.transaction(fn ->
      case Repo.transaction(fn ->
             with {:ok, front_user} <- create_front_user(params),
                  {:ok, user} <- create_rbac_user(front_user),
                  :ok <- connect_repository_providers(user.id, repository_providers),
                  {:ok, oidc_user_id} <-
                    create_oidc_user(oidc_user_id, user, password, skip_password_change),
                  {:ok, _oidc_user} <- connect_oidc_user(oidc_user_id, user.id) do
               user
             else
               {:error, error} ->
                 Repo.rollback(error)
             end
           end) do
        {:ok, user} ->
          user

        {:error, error} ->
          FrontRepo.rollback(error)
      end
    end)
  end

  defp connect_repository_providers(user_id, providers) when is_list(providers) do
    Enum.reduce_while(providers, :ok, fn provider, acc ->
      repo_host = map_provider_type(provider.type)

      repo_host_data = %{
        github_uid: provider.uid,
        login: provider.login,
        name: provider.login,
        permission_scope: Guard.FrontRepo.RepoHostAccount.register_scope()
      }

      case Guard.FrontRepo.RepoHostAccount.update_repo_host_account(
             user_id,
             repo_host,
             repo_host_data,
             reset: true
           ) do
        {:ok, _} ->
          {:cont, acc}

        {:error, changeset} ->
          Logger.error("Failed to create repo_host for user #{user_id}: #{inspect(changeset)}")
          {:halt, {:error, changeset.errors}}
      end
    end)
  end

  defp connect_repository_providers(_user_id, _), do: :ok

  defp map_provider_type(type),
    do:
      type
      |> InternalApi.User.RepositoryProvider.Type.key()
      |> Atom.to_string()
      |> String.downcase()
      |> String.to_atom()

  defp create_front_user(params) do
    Map.merge(params, %{
      salt: SaltGenerator.gen(),
      remember_created_at: DateTime.utc_now()
    })
    |> Guard.Store.User.Front.create()
  end

  defp create_rbac_user(front_user) do
    case Guard.Store.RbacUser.create(front_user.id, front_user.email, front_user.name) do
      :ok ->
        case Guard.Store.RbacUser.fetch(front_user.id) do
          nil -> {:error, :not_user}
          user -> {:ok, user}
        end

      :error ->
        {:error, :no_user}
    end
  end

  defp create_oidc_user(nil = _oidc_user_id, user, password, skip_password_change) do
    if Guard.OIDC.enabled?() do
      case Guard.OIDC.User.create_oidc_user(user,
             password_data: [password: password, temporary: not skip_password_change]
           ) do
        {:ok, oidc_user_id} ->
          Logger.info(
            "User created successfully: #{inspect(user)} and connected to OIDC user: #{inspect(oidc_user_id)}"
          )

          {:ok, oidc_user_id}

        error ->
          Logger.error("Failed to create user: #{inspect(error)}")

          {:error, :no_user}
      end
    else
      {:ok, ""}
    end
  end

  defp create_oidc_user(oidc_user_id, _user, _password, _skip_password_change) do
    Logger.info("OIDC id #{inspect(oidc_user_id)} preset, skipping creation of new OIDC user")
    {:ok, oidc_user_id}
  end

  defp connect_oidc_user(oidc_user_id, user_id) do
    if Guard.OIDC.enabled?() do
      Guard.Store.OIDCUser.connect_user(oidc_user_id, user_id)
    else
      {:ok, nil}
    end
  end

  @spec update(String.t(), user_params) ::
          {:ok, FrontRepo.User.t()} | {:error, List.t()} | {:error, Atom.t()}
  def update(user_id, user_params) do
    case Guard.Store.User.Front.update(user_id, user_params) do
      {:ok, user} ->
        Guard.Events.UserUpdated.publish(user.id, @exchange_name)

        {:ok, user}

      error ->
        error
    end
  end

  @spec change_email(String.t(), String.t()) ::
          {:ok, new_email :: String.t()} | {:error, String.t()}
  def change_email(user_id, email) do
    FrontRepo.transaction(fn ->
      Repo.transaction(fn ->
        with {:ok, user} <- change_front_email(user_id, email),
             {:ok, _} <- change_rbac_email(user_id, email),
             {:ok, _} <- change_oidc_email(user, email) do
          Guard.Events.UserUpdated.publish(user_id, @exchange_name)
          {:ok, email}
        else
          {:error, error} ->
            FrontRepo.rollback(error)
            {:error, error}
        end
      end)
      |> unwrap_transaction()
    end)
    |> unwrap_transaction()
  end

  defp unwrap_transaction({:ok, result}), do: result
  defp unwrap_transaction({:error, error}), do: {:error, error}

  @spec change_front_email(String.t(), String.t()) ::
          {:ok, FrontRepo.User.t()} | {:error, String.t()}
  defp change_front_email(user_id, email) do
    Guard.Store.User.Front.update(user_id, %{email: email})
    |> case do
      {:ok, user} ->
        {:ok, user}

      {:error, :user_not_found} ->
        {:error, "User not found"}

      {:error, :internal_error} ->
        {:error, "Internal error"}

      {:error, changeset_errors} ->
        error_string =
          changeset_errors
          |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
          |> Enum.map_join(". ", fn {field, changeset_errors} ->
            errors =
              changeset_errors
              |> Enum.map_join(", ", fn {error, _options} -> error end)

            field = String.capitalize("#{field}")

            "#{field} #{errors}"
          end)

        {:error, "#{error_string}"}
    end
  end

  @spec change_rbac_email(String.t(), String.t()) ::
          {:ok, Guard.Repo.RbacUser.t()} | {:error, String.t()}
  defp change_rbac_email(user_id, email) do
    Guard.Store.RbacUser.update(user_id, %{email: email})
    |> case do
      :ok ->
        {:ok, Guard.Store.RbacUser.fetch(user_id)}

      :error ->
        {:error, "Failed to change email"}
    end
  end

  @spec change_oidc_email(Guard.Repo.RbacUser.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  defp change_oidc_email(rbac_user, email) do
    if Guard.OIDC.enabled?() do
      Guard.Store.OIDCUser.fetch_by_user_id(rbac_user.id)
      |> case do
        {:ok, oidc_user} ->
          Guard.OIDC.User.update_oidc_user(oidc_user.oidc_user_id, rbac_user, email: email)
          |> case do
            {:ok, _} -> {:ok, email}
            {:error, _error} -> {:error, "Failed to change email"}
          end

        {:error, :not_found} ->
          {:error, "User not found"}
      end
    else
      {:ok, email}
    end
  end
end
