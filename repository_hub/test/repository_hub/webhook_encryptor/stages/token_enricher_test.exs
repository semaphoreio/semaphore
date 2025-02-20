defmodule RepositoryHub.WebhookEncryptor.TokenEnricherTest do
  use ExUnit.Case, async: false
  import Mock

  alias RepositoryHub.WebhookEncryptor.TokenEnricher

  describe "handle_events/3" do
    test "transforms multiple events" do
      with_mocks([
        {RepositoryHub.UserClient, [],
         [
           get_repository_token: fn
             "github_oauth_token", "owner_id" -> {:ok, "github_oauth_token.owner_id"}
             "bitbucket", "owner_id" -> {:ok, "bitbucket.owner_id"}
             _integration_type, _owner_id -> {:error, :reason}
           end
         ]},
        {RepositoryHub.RepositoryIntegratorClient, [],
         [
           get_token: fn
             1, "owner/name" -> {:ok, "github_app.owner_name"}
             _integration_type, _slug -> {:error, :reason}
           end
         ]}
      ]) do
        events = [
          event("github_oauth_token", "owner_id", "owner", "repo"),
          event("github_app", "owner_id", "owner", "name"),
          event("bitbucket", "owner_id", "owner", "repo"),
          event("github_oauth_token", "owner", "owner", "repo"),
          event("github_app", "failure_id", "owner", "repo")
        ]

        assert {:noreply, new_events, %{}} = TokenEnricher.handle_events(events, self(), %{})

        assert MapSet.new(new_events, & &1.token) ==
                 MapSet.new([
                   "github_oauth_token.owner_id",
                   "github_app.owner_name",
                   "bitbucket.owner_id"
                 ])
      end
    end
  end

  describe "transform_event/1" do
    test "when event has github oauth token integration, then returns the event with the token" do
      with_mock RepositoryHub.UserClient,
        get_repository_token: fn
          "github_oauth_token", owner_id ->
            {:ok, "github_oauth_token.#{owner_id}"}
        end do
        event = event("github_oauth_token", "owner_id", "owner", "repo")
        assert {:ok, %{token: token}} = TokenEnricher.transform_event(event)
        assert token == "github_oauth_token.owner_id"
      end
    end

    test "when event has github app integration, then returns the event with the token" do
      with_mock RepositoryHub.RepositoryIntegratorClient,
        get_token: fn
          1, slug ->
            {:ok, "github_app.#{slug}"}
        end do
        event = event("github_app", "owner_id", "owner", "repo")
        assert {:ok, %{token: token}} = TokenEnricher.transform_event(event)
        assert token == "github_app.owner/repo"
      end
    end

    test "when event has bitbucket integration, then returns the event with the token" do
      with_mock RepositoryHub.UserClient,
        get_repository_token: fn
          "bitbucket", owner_id -> {:ok, "bitbucket.#{owner_id}"}
        end do
        event = event("bitbucket", "owner_id", "owner", "repo")
        assert {:ok, %{token: token}} = TokenEnricher.transform_event(event)
        assert token == "bitbucket.owner_id"
      end
    end

    test "when user client fails, then returns an error" do
      with_mock RepositoryHub.UserClient,
        get_repository_token: fn
          "github_oauth_token", _owner_id -> {:error, :reason}
        end do
        event = event("github_oauth_token", "owner_id", "owner", "repo")
        assert {:error, :reason} = TokenEnricher.transform_event(event)
      end
    end

    test "when repository integrator client fails, then returns an error" do
      with_mock RepositoryHub.RepositoryIntegratorClient,
        get_token: fn
          1, _slug -> {:error, :reason}
        end do
        event = event("github_app", "owner_id", "owner", "repo")
        assert {:error, :reason} = TokenEnricher.transform_event(event)
      end
    end
  end

  defp event(integration_type, owner_id, owner, name) do
    %{
      project_id: "project_id",
      integration_type: integration_type,
      project_owner_id: owner_id,
      git_repository: %{owner: owner, name: name}
    }
  end
end
