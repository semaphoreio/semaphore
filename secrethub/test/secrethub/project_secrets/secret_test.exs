defmodule Secrethub.ProjectSecrets.SecretTest do
  use ExUnit.Case, async: true

  alias Secrethub.ProjectSecrets.Secret
  alias Secrethub.Model.Content
  alias Secrethub.Model.EnvVar
  alias Secrethub.Model.File

  alias Support.Factories.Model, as: ModelFactory

  setup_all [
    :prepare_data,
    :prepare_params
  ]

  describe "changeset/2" do
    test "casts necessary fields", %{params: params} do
      assert changeset = Secret.changeset(%Secret{}, %{params | content: %{}, used_by: nil})
      assert %Ecto.Changeset{valid?: true} = changeset
      assert secret = Ecto.Changeset.apply_changes(changeset)
      assert secret.name == params[:name]
      assert secret.description == params[:description]
      assert secret.project_id == params[:project_id]
      assert secret.org_id == params[:org_id]
      assert secret.created_by == params[:created_by]
      assert secret.updated_by == params[:updated_by]

      assert secret.content == %Content{
               env_vars: [],
               files: []
             }

      assert secret.content_encrypted != nil
    end

    test "checks required fields", %{params: params} do
      required_fields = ~w(name project_id org_id created_by updated_by)a

      for field <- required_fields do
        assert %Ecto.Changeset{valid?: false, errors: [{^field, {"can't be blank", _}}]} =
                 Secret.changeset(%Secret{}, Map.delete(params, field))
      end
    end

    test "checks if content exists", %{params: params} do
      assert %Ecto.Changeset{errors: [content: {"can't be blank", _}]} =
               Secret.changeset(%Secret{}, Map.delete(params, :content))
    end

    test "allows empty content", %{params: params} do
      assert changeset = Secret.changeset(%Secret{}, %{params | content: %{}})
      assert %Ecto.Changeset{valid?: true} = changeset

      assert %Secret{content: %Content{env_vars: [], files: []}} =
               Ecto.Changeset.apply_changes(changeset)
    end

    test "casts content", %{params: params} do
      assert changeset = Secret.changeset(%Secret{}, params)
      assert %Ecto.Changeset{valid?: true} = changeset

      assert %Secret{
               content: %Content{
                 env_vars: [
                   %EnvVar{name: "VAR1", value: "value1"},
                   %EnvVar{name: "VAR2", value: "value2"}
                 ],
                 files: [
                   %File{path: "/home/path1", content: "content1"},
                   %File{path: "/home/path2", content: "content2"}
                 ]
               }
             } = Ecto.Changeset.apply_changes(changeset)
    end

    test "allows missing checkout", %{params: params} do
      assert changeset = Secret.changeset(%Secret{}, Map.delete(params, :used_by))
      assert %Ecto.Changeset{valid?: true} = changeset
      assert %Secret{used_by: nil} = Ecto.Changeset.apply_changes(changeset)
    end

    test "does not cast checkout", %{params: params} do
      assert changeset = Secret.changeset(%Secret{}, %{params | used_by: %{}})
      assert %Ecto.Changeset{valid?: true, errors: []} = changeset
      assert %Secret{used_by: nil} = Ecto.Changeset.apply_changes(changeset)
    end

    test "validates name format", %{params: params} do
      assert %Ecto.Changeset{valid?: true} =
               Secret.changeset(%Secret{}, %{params | name: "secret123"})

      assert changeset = %Ecto.Changeset{valid?: true} = Secret.changeset(%Secret{}, params)

      assert changeset
             |> Ecto.Changeset.get_change(:name)
             |> String.equivalent?(params[:name])
    end

    test "does not allow too long description", %{params: params} do
      assert changeset =
               Secret.changeset(%Secret{}, %{
                 params
                 | content: %{},
                   used_by: nil,
                   description: String.duplicate("a", 256)
               })

      assert %Ecto.Changeset{valid?: false} = changeset
    end
  end

  defp prepare_data(_ctx) do
    {:ok,
     org_id: Ecto.UUID.generate(),
     project_id: Ecto.UUID.generate(),
     project_id: Ecto.UUID.generate(),
     user_id: Ecto.UUID.generate(),
     now: DateTime.utc_now(),
     content: ModelFactory.prepare_content_params(),
     checkout: ModelFactory.prepare_checkout_params()}
  end

  defp prepare_params(ctx) do
    {:ok,
     params: %{
       name: "dt.#{ctx.project_id}",
       description: "Description",
       project_id: ctx.project_id,
       org_id: ctx.org_id,
       created_by: ctx.user_id,
       updated_by: ctx.user_id,
       content: ctx.content,
       used_by: ctx.checkout,
       used_at: DateTime.truncate(ctx.now, :second)
     }}
  end
end
