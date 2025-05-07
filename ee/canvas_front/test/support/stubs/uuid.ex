defmodule Support.Stubs.UUID do
  def gen do
    Ecto.UUID.generate()
  end
end
