defmodule Guard.OnPrem.Init do
  require Logger

  def init do
    Logger.info("[OnPrem Init] Initializing data for onprem instance")

    if Guard.FrontRepo.aggregate(Guard.FrontRepo.Organization, :count, :id) > 0 do
      Logger.info("[OnPrem Init] Organization already exists, skiping data initialization")
      exit({:shutdown, 0})
    end

    org_name = fetch_env_or_die("ORGANIZATION_SEED_ORG_NAME")
    org_username = fetch_env_or_die("ORGANIZATION_SEED_ORG_USERNAME")
    owner_github_username = fetch_env_or_die("ORGANIZATION_SEED_OWNER_GITHUB_USERNAME")
    owner_email = fetch_env_or_die("ORGANIZATION_SEED_OWNER_EMAIL")

    github_user = get_github_user(owner_github_username)
    owner = create_owner(owner_email, github_user.name)
    org = create_organization(org_username, org_name, owner.id)
    add_org_memeber(org.id, github_user.login, github_user.id, "github")
    create_repo_host_account(owner.id, github_user.login, github_user.id, github_user.name)
    create_oauth_connection(owner.id, github_user.id)
  end

  defp create_owner(email, username, password \\ nil) do
    Logger.info("[OnPrem Init] Creating owner account")

    Guard.User.Actions.create(%{name: username, email: email, password: password})
    |> case do
      {:ok, owner} ->
        owner

      {:error, e} ->
        Logger.error("[OnPrem Init] Error while creating owner account #{inspect(e)}")
        exit({:shutdown, 1})
    end
  end

  defp create_organization(org_username, org_name, creator_id) do
    Logger.info("[OnPrem Init] Creating default org")

    %Guard.FrontRepo.Organization{
      username: org_username,
      name: org_name,
      open_source: false,
      restricted: true,
      creator_id: creator_id
    }
    |> Guard.FrontRepo.insert()
    |> case do
      {:ok, org} ->
        Logger.info("[OnPrem Init] Organization's id: #{org.id}")
        Logger.info("[OnPrem Init] Organization's username: #{org.username}")
        org

      {:error, _} ->
        Logger.error("[OnPrem Init] Error while creating default org")
        exit({:shutdown, 1})
    end
  end

  defp add_org_memeber(org_id, github_username, github_uid, repo_host) do
    Logger.info("[OnPrem Init] Adding owner as org member")

    %Guard.FrontRepo.Member{
      github_uid: to_string(github_uid),
      github_username: github_username,
      repo_host: repo_host,
      organization_id: org_id
    }
    |> Guard.FrontRepo.insert()
    |> case do
      {:ok, member} ->
        member

      {:error, _} ->
        Logger.error("[OnPrem Init] Error while creating organization member")
        exit({:shutdown, 1})
    end
  end

  defp create_repo_host_account(user_id, github_username, github_uid, github_name) do
    Logger.info("[OnPrem Init] Creating repo_host_account")

    Guard.FrontRepo.RepoHostAccount.create(%{
      user_id: user_id,
      login: github_username,
      github_uid: to_string(github_uid),
      name: github_name,
      permission_scope: "user:email",
      repo_host: "github"
    })
    |> case do
      {:ok, rha} ->
        rha

      {:error, _} ->
        Logger.error("[OnPrin Init] Error while creating repo_host_account")
        exit({:shutdown, 1})
    end
  end

  defp create_oauth_connection(user_id, github_uid) do
    Logger.info("[OnPrem Init] Creating OAuth connection to Github for default user")

    %Guard.FrontRepo.OauthConnection{
      user_id: user_id,
      github_uid: to_string(github_uid),
      token: "",
      provider: "github"
    }
    |> Guard.FrontRepo.insert()
    |> case do
      {:ok, oauth} ->
        oauth

      {:error, _} ->
        Logger.error(
          "[OnPrem Init] Error while creating OAuth connection to Github for default user"
        )

        exit({:shutdown, 1})
    end
  end

  defp fetch_env_or_die(env_name) do
    case System.fetch_env(env_name) do
      {:ok, value} ->
        value

      :error ->
        Logger.info("ERROR: #{env_name} environment variable not provided")
        exit({:shutdown, 1})
    end
  end

  defp get_github_user(github_username) do
    case HTTPoison.get("https://api.github.com/users/#{github_username}") do
      {:ok, response} ->
        case response.status_code do
          200 ->
            {:ok, resp_body} = Jason.decode(response.body)

            %{
              id: resp_body["id"],
              name: resp_body["name"] || github_username,
              login: resp_body["login"] || github_username
            }

          status_code ->
            Logger.error(
              "[OnPrem Init] Got status code #{status_code} while fetch owner github info: #{inspect(response)}"
            )

            exit({:shutdown, 1})
        end

      {:error, err} ->
        Logger.error(
          "[OnPrem Init] Error while trying to fetch owner github info: #{inspect(err)}"
        )

        exit({:shutdown, 1})
    end
  end
end
