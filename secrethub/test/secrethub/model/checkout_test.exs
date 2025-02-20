defmodule Secrethub.Model.CheckoutTest do
  use ExUnit.Case, async: true
  alias Secrethub.Model.Checkout

  setup_all do
    {:ok,
     [
       params: %{
         job_id: "test",
         pipeline_id: "test",
         workflow_id: "test",
         hook_id: "test",
         project_id: "test",
         user_id: "test"
       }
     ]}
  end

  describe "changeset/2" do
    test "maps all fields", %{params: params} do
      assert changeset = Checkout.changeset(%Checkout{}, params)
      assert changeset.valid?

      assert checkout = Ecto.Changeset.apply_changes(changeset)

      for {key, value} <- params do
        assert ^value = Map.get(checkout, key)
      end
    end

    test "no fields are required", %{params: params} do
      for {key, _value} <- params do
        assert %Ecto.Changeset{valid?: true} =
                 Checkout.changeset(%Checkout{}, Map.delete(params, key))
      end
    end
  end
end
