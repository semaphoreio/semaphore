defmodule Secrethub.Secret.Test do
  use ExUnit.Case, async: true

  alias Secrethub.Secret
  alias Secrethub.Model.Content
  alias Secrethub.Model.EnvVar
  alias Secrethub.Model.File
  alias Support.Factories.Model, as: ModelFactory
  alias Secrethub.Repo

  setup_all [
    :prepare_data,
    :prepare_params
  ]

  describe ".update_usage" do
    setup [:repo_checkout, :prepare_secret]

    test "does not change updated_at time", ctx do
      {:ok, _} = Secret.update_usage(ctx.secret, %{job_id: "job_id"})
      {:ok, secret} = Secret.find(ctx.secret.org_id, ctx.secret.id)
      assert secret.updated_at == ctx.secret.updated_at
    end
  end

  describe "changeset/2" do
    test "checks required fields", %{params: params} do
      required_fields = ~w(name org_id)a

      for field <- required_fields do
        assert %Ecto.Changeset{valid?: false, errors: [{^field, {"can't be blank", _}}]} =
                 Secret.changeset(%Secret{}, Map.delete(params, field))
      end
    end

    test "content is put into content", %{params: params} do
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

    test "allows empty content", %{params: params} do
      assert changeset = Secret.changeset(%Secret{}, %{params | content: %{}})
      assert %Ecto.Changeset{valid?: true} = changeset

      assert %Secret{content: %Content{env_vars: [], files: []}} =
               Ecto.Changeset.apply_changes(changeset)
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

  test "content_encrypted field is filled", %{params: params} do
    assert changeset = Secret.changeset(%Secret{}, params)
    assert %Ecto.Changeset{valid?: true} = changeset
    secret = Ecto.Changeset.apply_changes(changeset)
    assert secret.content_encrypted != ""
  end

  defp prepare_data(_ctx) do
    {:ok,
     org_id: Ecto.UUID.generate(),
     user_id: Ecto.UUID.generate(),
     now: DateTime.utc_now(),
     content: ModelFactory.prepare_content_params(),
     checkout: ModelFactory.prepare_checkout_params()}
  end

  defp prepare_params(ctx) do
    {:ok,
     params: %{
       name: "my-secret",
       description: "Description",
       org_id: ctx.org_id,
       created_by: ctx.user_id,
       updated_by: ctx.user_id,
       content: %{"data" => ctx.content},
       used_by: ctx.checkout,
       used_at: DateTime.truncate(ctx.now, :second)
     }}
  end

  defp repo_checkout(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  defp prepare_secret(ctx) do
    {:ok, secret} =
      Secrethub.Secret.save(
        ctx.org_id,
        ctx.user_id,
        ctx.params.name,
        ctx.params.content
      )

    {:ok, secret: secret}
  end
end
