defmodule RepositoryHub.WebhookEncryptor.ProjectSplitterTest do
  use ExUnit.Case, async: false
  import Mock

  alias RepositoryHub.WebhookEncryptor.ProjectSplitter
  alias RepositoryHub.ProjecthubClient

  describe "handle_messages/3" do
    test "splits multiple events" do
      with_mock ProjecthubClient,
        list_keyset: fn
          "org1", page_token: "" -> {:ok, %{projects: [], next_page_token: ""}}
          "org2", page_token: "" -> {:ok, %{projects: page_of_projects(1..3), next_page_token: ""}}
          "org3", page_token: "" -> {:ok, %{projects: page_of_projects(4..6), next_page_token: "next"}}
          "org3", page_token: "next" -> {:ok, %{projects: page_of_projects(7..9), next_page_token: ""}}
          "org4", page_token: "" -> {:error, %{code: :INTERNAL_ERROR, message: "Internal error"}}
          "org5", page_token: "" -> {:ok, %{projects: page_of_projects(10..12), next_page_token: "next"}}
          "org5", page_token: "next" -> {:error, %{code: :INTERNAL_ERROR, message: "Internal error"}}
        end do
        assert {:noreply, projects, %{}} =
                 1..5 |> Enum.into([], &%{org_id: "org#{&1}"}) |> ProjectSplitter.handle_events(self(), %{})

        assert MapSet.new(projects, & &1.git_repository.name) == 1..9 |> MapSet.new(&"repo#{&1}")
      end
    end
  end

  describe "split_into_project_events/1" do
    test "when there are no projects then returns an empty list" do
      with_mock ProjecthubClient,
        list_keyset: fn
          _org_id, _opts -> {:ok, %{projects: [], next_page_token: ""}}
        end do
        assert {:ok, []} = ProjectSplitter.to_project_events(%{org_id: "org_id"})
      end
    end

    test "retains previous fields and add new ones" do
      with_mock ProjecthubClient,
        list_keyset: fn _org_id, _opts ->
          {:ok, %{projects: page_of_projects(1..1), next_page_token: ""}}
        end do
        assert {:ok, [project]} = ProjectSplitter.to_project_events(%{org_id: "org_id"})

        assert {:ok, _} = UUID.info(project.project_id)
        assert {:ok, _} = UUID.info(project.project_owner_id)
        assert {:ok, _} = UUID.info(project.repository_id)
        assert project.git_repository.owner == "owner1"
        assert project.git_repository.name == "repo1"
      end
    end

    test "when there is one page then returns a list of projects" do
      with_mock ProjecthubClient,
        list_keyset: fn _org_id, _opts ->
          {:ok, %{projects: page_of_projects(1..3), next_page_token: ""}}
        end do
        assert {:ok, projects} = ProjectSplitter.to_project_events(%{org_id: "org_id"})
        assert length(projects) == 3

        assert MapSet.new(projects, & &1.git_repository.owner) == MapSet.new(["owner1", "owner2"])
        assert MapSet.new(projects, & &1.git_repository.name) == MapSet.new(["repo1", "repo2", "repo3"])
      end
    end

    test "when there are multiple pages then returns a list of projects" do
      with_mock ProjecthubClient,
        list_keyset: fn
          _org_id, page_token: "" ->
            {:ok, %{projects: page_of_projects(1..10), next_page_token: "next"}}

          _org_id, page_token: "next" ->
            {:ok, %{projects: page_of_projects(11..15), next_page_token: ""}}
        end do
        assert {:ok, projects} = ProjectSplitter.to_project_events(%{org_id: "org_id"})
        assert length(projects) == 15

        assert MapSet.new(projects, & &1.git_repository.owner) == MapSet.new(["owner1", "owner2"])

        assert MapSet.new(projects, & &1.git_repository.name) ==
                 1..15 |> Enum.map(&"repo#{&1}") |> MapSet.new()
      end
    end

    test "when there is an error in the first call then returns the error" do
      with_mock ProjecthubClient,
        list_keyset: fn _org_id, _opts ->
          {:error, %{code: :INTERNAL_ERROR, message: "Internal error"}}
        end do
        assert {:error, %{code: :INTERNAL_ERROR, message: "Internal error"}} =
                 ProjectSplitter.to_project_events(%{org_id: "org_id"})
      end
    end

    test "when there is an error in the second call then returns the error" do
      with_mock ProjecthubClient,
        list_keyset: fn
          _org_id, page_token: "" ->
            {:ok, %{projects: page_of_projects(1..10), next_page_token: "next"}}

          _org_id, page_token: "next" ->
            {:error, %{code: :INTERNAL_ERROR, message: "Internal error"}}
        end do
        assert {:error, %{code: :INTERNAL_ERROR, message: "Internal error"}} =
                 ProjectSplitter.to_project_events(%{org_id: "org_id"})
      end
    end
  end

  defp page_of_projects(range) do
    integration_types = Stream.cycle([:GITHUB_OAUTH_TOKEN, :GITHUB_APP, :BITBUCKET])
    owner_names = Stream.cycle(["owner1", "owner1", "owner2"])

    Enum.map(Stream.zip([range, integration_types, owner_names]), fn {i, it, owner} ->
      project(it, owner, "repo#{i}")
    end)
  end

  defp project(integration_type, owner, name) do
    %{
      metadata: %{
        id: UUID.uuid4(),
        owner_id: UUID.uuid4()
      },
      spec: %{
        repository: %{
          id: UUID.uuid4(),
          owner: owner,
          name: name,
          integration_type: integration_type
        }
      }
    }
  end
end
