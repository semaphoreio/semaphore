defmodule RepositoryHub.ValidatorTest do
  use ExUnit.Case, async: true
  doctest RepositoryHub.Validator, import: true
  alias RepositoryHub.Validator
  import Validator, only: [validate: 2]

  describe "Validator usage" do
    test "some examples" do
      contract = [
        chain: [
          take!: [from!: :number_of_items, from!: :item_price],
          all: [
            chain: [
              check: fn [number_of_items, item_price] -> number_of_items * item_price < 10_000 end,
              error_message: "Total must be less than 10000"
            ],
            chain: [
              check: fn [number_of_items, item_price] ->
                String.length("$#{number_of_items * item_price}.00") < 9
              end,
              error_message: fn _error, [number_of_items, item_price] ->
                "`$#{number_of_items * item_price}.00` must fit on 9 digit screens"
              end
            ]
          ]
        ]
      ]

      registry = %{
        number_of_items: 10,
        item_price: 900
      }

      assert {:ok, ^registry} = validate(registry, contract)

      registry = %{
        number_of_items: 10,
        item_price: 1_000
      }

      assert {:error, "Total must be less than 10000, `$10000.00` must fit on 9 digit screens"} =
               validate(registry, contract)
    end

    test "deferring expensive validations" do
      contract = [
        chain: [
          all: [
            chain: [{:from!, :user_id}, :is_uuid],
            chain: [{:from!, :email}, :is_string, :is_not_empty, eq: "joe@example.com"]
          ],
          chain: [
            {:from!, :email},
            fn
              "joe@example.com" -> true
              _ -> raise "I should have never been called"
            end
          ]
        ]
      ]

      user = %{
        email: "joe@example.com",
        user_id: Ecto.UUID.generate()
      }

      assert {:ok, ^user} = validate(user, contract)

      user = %{
        email: "jones@example.com",
        user_id: Ecto.UUID.generate()
      }

      assert {:error, _} = validate(user, contract)
    end

    test "take" do
      contract = [
        chain: [
          {:take!, [identity: 1, identity: 2]},
          {fn [a, b] -> a + b end, []},
          {:eq, 3}
        ]
      ]

      a_number = 3

      assert {:ok, ^a_number} = validate(a_number, contract)
    end

    test "check two values at once" do
      contract = [
        all: [
          chain: [{:from!, :height}, :is_integer],
          chain: [{:from!, :weight}, :is_integer]
        ],
        chain: [
          {:take!, [{:from!, :weight}, {:from!, :height}]},
          {fn [weight, height] -> weight / height end, []},
          all: [
            gt: 1.5,
            lt: 3.0,
            gt: 1.9
          ]
        ]
      ]

      measurements = %{
        weight: 200,
        height: 100
      }

      assert {:ok, ^measurements} = validate(measurements, contract)

      measurements = %{
        weight: 220,
        height: 150
      }

      assert {:error, _} = validate(measurements, contract)
    end
  end
end
