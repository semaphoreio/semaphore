defmodule Support.Factories.Favorite do
  def insert(attr \\ %{}) do
    default_attr = %{
      user_id: Ecto.UUID.generate(),
      favorite_id: Ecto.UUID.generate(),
      organization_id: Ecto.UUID.generate(),
      kind: "PROJECT"
    }

    attr = Map.merge(default_attr, attr)

    %Guard.FrontRepo.Favorite{
      user_id: attr[:user_id],
      favorite_id: attr[:favorite_id],
      organization_id: attr[:organization_id],
      kind: attr[:kind]
    }
    |> Guard.FrontRepo.insert()
  end
end
