defmodule PreFlightChecks.ProjectPFC.Model.ProjectPFCTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias PreFlightChecks.ProjectPFC.Model.ProjectPFC

  describe "project pre-flight checks changeset" do
    test "without organization_id is invalid" do
      params = %{
        project_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: [],
          agent: %{
            machine_type: "e2-standard-2",
            os_image: "ubuntu2204"
          }
        }
      }

      assert_invalid(params, &assert_error_required_organization_id/1)
    end

    test "without project_id is invalid" do
      params = %{
        organization_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: [],
          agent: %{
            machine_type: "e2-standard-2",
            os_image: "ubuntu2204"
          }
        }
      }

      assert_invalid(params, &assert_error_required_project_id/1)
    end

    test "without requester_id is invalid" do
      params = %{
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: [],
          agent: %{
            machine_type: "e2-standard-2",
            os_image: "ubuntu2204"
          }
        }
      }

      assert_invalid(params, &assert_error_required_requester_id/1)
    end

    test "without commands and secrets is invalid" do
      params = %{
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: [],
          secrets: [],
          agent: %{
            machine_type: "e2-standard-2",
            os_image: "ubuntu2204"
          }
        }
      }

      assert_invalid(params, &assert_empty_commands_error/1)
    end

    test "without secrets is valid" do
      params = %{
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: [],
          agent: %{
            machine_type: "e2-standard-2",
            os_image: "ubuntu2204"
          }
        }
      }

      assert_valid(params)
    end

    test "without commands is invalid" do
      params = %{
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: [],
          secrets: ["POSTGRES_PASSWORD", "SESSION_SECRET"],
          agent: %{
            machine_type: "e2-standard-2",
            os_image: "ubuntu2204"
          }
        }
      }

      assert_invalid(params, &assert_empty_commands_error/1)
    end

    test "without agent is valid" do
      params = %{
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: ["POSTGRES_PASSWORD", "SESSION_SECRET"]
        }
      }

      assert_valid(params)
    end

    test "without agent's machine type is invalid" do
      params = %{
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: ["POSTGRES_PASSWORD", "SESSION_SECRET"],
          agent: %{
            os_image: "ubuntu2204"
          }
        }
      }

      assert_invalid(params, &assert_agent_errors(&1, [:machine_type]))
    end

    test "without agent's OS image is valid" do
      params = %{
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: ["POSTGRES_PASSWORD", "SESSION_SECRET"],
          agent: %{
            machine_type: "self-hosted-agent"
          }
        }
      }

      assert_valid(params)
    end

    test "with everything is valid" do
      params = %{
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: ["POSTGRES_PASSWORD", "SESSION_SECRET"],
          agent: %{
            machine_type: "e2-standard-2",
            os_image: "ubuntu2204"
          }
        }
      }

      assert_valid(params)
    end
  end

  defp assert_valid(params) do
    pfc_changeset = ProjectPFC.changeset(%ProjectPFC{}, params)
    assert pfc_changeset.valid?

    changes = pfc_changeset.changes
    def_changes = changes.definition.changes

    assert changes.organization_id == params[:organization_id]
    assert changes.project_id == params[:project_id]
    assert def_changes.commands == params[:definition][:commands]
    assert def_changes.secrets == params[:definition][:secrets]
  end

  defp assert_invalid(params, assert_fun) do
    pfc_changeset = ProjectPFC.changeset(%ProjectPFC{}, params)
    assert not pfc_changeset.valid?

    assert_fun.(pfc_changeset)
  end

  defp assert_empty_commands_error(changeset) do
    errors = changeset.changes.definition.errors

    assert [commands: {msg, opts}] = errors
    assert "should have at least %{count} item(s)" = msg
    assert 1 = opts[:count]
  end

  defp assert_agent_errors(changeset, error_fields) do
    errors = changeset.changes.definition.changes.agent.errors

    Enum.each(error_fields, fn error_field ->
      assert Keyword.has_key?(errors, error_field)
    end)
  end

  defp assert_error_required_organization_id(changeset),
    do: assert_field_required_error(changeset, :organization_id)

  defp assert_error_required_project_id(changeset),
    do: assert_field_required_error(changeset, :project_id)

  defp assert_error_required_requester_id(changeset),
    do: assert_field_required_error(changeset, :requester_id)

  defp assert_field_required_error(%Ecto.Changeset{errors: errors}, field),
    do: assert([{^field, {"can't be blank", [validation: :required]}}] = errors)
end
