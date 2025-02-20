defmodule Front.Sufix do
  @data [
    "eins",
    "zwei",
    "drei",
    "vier",
    "funf",
    "sechs",
    "sieben",
    "acht",
    "neun",
    "zehn",
    "uno",
    "due",
    "tre",
    "quattro",
    "cinque",
    "sei",
    "sette",
    "otto",
    "nove",
    "dieci",
    "un",
    "deux",
    "trois",
    "quatre",
    "cinq",
    "six",
    "sept",
    "huit",
    "neuf",
    "dix",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "un",
    "dos",
    "tres",
    "cuatro",
    "cinco",
    "seis",
    "siete",
    "ocho",
    "nueve",
    "diez"
  ]

  def on_position(position) do
    @data |> Enum.at(position - 1)
  end

  def contains?(position) do
    Enum.count(@data) >= position
  end

  def with_sufix(name, 0), do: name

  def with_sufix(name, position) do
    "#{name}-#{on_position(position)}"
  end
end
