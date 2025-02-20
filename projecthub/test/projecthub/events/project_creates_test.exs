defmodule Projecthub.Events.ProjectCreatedTest do
  use Projecthub.DataCase
  alias Projecthub.Events.ProjectCreated
  require Logger

  describe ".publish" do
    test "it emits an event to rabbit" do
      {:ok, project} = Support.Factories.Project.create()

      with_mock Tackle, publish: fn _message, _options -> :ok end do
        {:ok, _} = ProjectCreated.publish(%{project_id: project.id, organization_id: project.organization_id})
      end
    end
  end
end
