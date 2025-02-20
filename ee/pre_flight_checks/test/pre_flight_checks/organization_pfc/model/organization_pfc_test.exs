defmodule PreFlightChecks.OrganizationPFC.Model.OrganizationPFCTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias PreFlightChecks.OrganizationPFC.Model.OrganizationPFC

  describe "organization pre-flight checks changeset" do
    test "without organization_id is invalid" do
      params = %{
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: [],
          agent: %{
            machine_type: "e1-standard-2",
            os_image: "ubuntu1804"
          }
        }
      }

      assert_invalid(params, &assert_error_required_organization_id/1)
    end

    test "without requester_id is invalid" do
      params = %{
        organization_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: [],
          agent: %{
            machine_type: "e1-standard-2",
            os_image: "ubuntu1804"
          }
        }
      }

      assert_invalid(params, &assert_error_required_requester_id/1)
    end

    test "without commands and secrets is invalid" do
      params = %{
        organization_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: [],
          secrets: [],
          agent: %{
            machine_type: "e1-standard-2",
            os_image: "ubuntu1804"
          }
        }
      }

      assert_invalid(params, &assert_empty_commands_error/1)
    end

    test "without secrets is valid" do
      params = %{
        organization_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: [],
          agent: %{
            machine_type: "e1-standard-2",
            os_image: "ubuntu1804"
          }
        }
      }

      assert_valid(params)
    end

    test "without commands is invalid" do
      params = %{
        organization_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: [],
          secrets: ["POSTGRES_PASSWORD", "SESSION_SECRET"],
          agent: %{
            machine_type: "e1-standard-2",
            os_image: "ubuntu1804"
          }
        }
      }

      assert_invalid(params, &assert_empty_commands_error/1)
    end

    test "with eveything is valid" do
      params = %{
        organization_id: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        definition: %{
          commands: ["git checkout master", "mix compile"],
          secrets: ["POSTGRES_PASSWORD", "SESSION_SECRET"]
        }
      }

      assert_valid(params)
    end
  end

  defp assert_valid(params) do
    pfc_changeset = OrganizationPFC.changeset(%OrganizationPFC{}, params)
    assert pfc_changeset.valid?

    changes = pfc_changeset.changes
    def_changes = changes.definition.changes

    assert changes.organization_id == params[:organization_id]
    assert def_changes.commands == params[:definition][:commands]
    assert def_changes.secrets == params[:definition][:secrets]
  end

  defp assert_invalid(params, assert_fun) do
    pfc_changeset = OrganizationPFC.changeset(%OrganizationPFC{}, params)
    assert not pfc_changeset.valid?

    assert_fun.(pfc_changeset)
  end

  defp assert_empty_commands_error(changeset) do
    errors = changeset.changes.definition.errors

    assert [commands: {msg, opts}] = errors
    assert "should have at least %{count} item(s)" = msg
    assert 1 = opts[:count]
  end

  defp assert_error_required_organization_id(changeset),
    do: assert_field_required_error(changeset, :organization_id)

  defp assert_error_required_requester_id(changeset),
    do: assert_field_required_error(changeset, :requester_id)

  defp assert_field_required_error(%Ecto.Changeset{errors: errors}, field),
    do: assert([{^field, {"can't be blank", [validation: :required]}}] = errors)
end
