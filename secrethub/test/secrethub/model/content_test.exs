defmodule Secrethub.Model.EnvVarTest do
  use ExUnit.Case, async: true

  alias Secrethub.Model.Content
  alias Secrethub.Model.EnvVar
  alias Secrethub.Model.File

  describe "changeset/2" do
    test "with empty content" do
      assert changeset = Content.changeset(%Content{}, %{})
      assert %Ecto.Changeset{valid?: true} = changeset
      assert %Content{env_vars: [], files: []} = Ecto.Changeset.apply_changes(changeset)
    end

    test "with invalid env_vars structure" do
      assert changeset = Content.changeset(%Content{}, %{env_vars: %{"FOO" => "bar"}})
      assert %Ecto.Changeset{errors: [env_vars: {"is invalid", _}], valid?: false} = changeset
    end

    test "with invalid files structure" do
      assert changeset = Content.changeset(%Content{}, %{files: %{"/home/foo" => "bar"}})
      assert %Ecto.Changeset{errors: [files: {"is invalid", _}], valid?: false} = changeset
    end

    test "with env variable with non-empty name and value" do
      assert changeset =
               Content.changeset(%Content{}, %{env_vars: [%{name: "FOO", value: "bar"}]})

      assert %Ecto.Changeset{valid?: true} = changeset

      assert %Content{env_vars: [%EnvVar{name: "FOO", value: "bar"}], files: []} =
               Ecto.Changeset.apply_changes(changeset)
    end

    test "with empty env variable name" do
      assert %Ecto.Changeset{
               changes: %{env_vars: [%Ecto.Changeset{valid?: false}]},
               valid?: false
             } = Content.changeset(%Content{}, %{env_vars: [%{name: "", value: "bar"}]})
    end

    test "with empty env variable value" do
      assert %Ecto.Changeset{
               changes: %{env_vars: [%Ecto.Changeset{valid?: false}]},
               valid?: false
             } = Content.changeset(%Content{}, %{env_vars: [%{name: "FOO", value: ""}]})
    end

    test "with file with non-empty path and content" do
      assert changeset =
               Content.changeset(%Content{}, %{files: [%{path: "/home/foo", content: "content"}]})

      assert %Ecto.Changeset{valid?: true} = changeset

      assert %Content{
               files: [%File{path: "/home/foo", content: "content"}],
               env_vars: []
             } = Ecto.Changeset.apply_changes(changeset)
    end

    test "with empty file path" do
      assert %Ecto.Changeset{changes: %{files: [%Ecto.Changeset{valid?: false}]}, valid?: false} =
               Content.changeset(%Content{}, %{files: [%{path: "", content: "content"}]})
    end

    test "with empty file content" do
      assert %Ecto.Changeset{changes: %{files: [%Ecto.Changeset{valid?: false}]}, valid?: false} =
               Content.changeset(%Content{}, %{files: [%{path: "/home/foo", content: ""}]})
    end

    test "with too much data" do
      files = [
        %{path: "/tmp/a", content: String.duplicate("x", 1024 * 1024 * 4)},
        %{path: "/tmp/b", content: String.duplicate("x", 1024 * 1024 * 4)}
      ]

      assert %Ecto.Changeset{
               errors: [size: {"content is too big", _}],
               valid?: false
             } = Content.changeset(%Content{}, %{files: files})
    end
  end
end
