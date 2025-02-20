defmodule Support.HTTPMock do
  def success do
    {:ok, %HTTPoison.Response{body: "", headers: [], status_code: 200}}
  end

  def failure do
    {:error, %HTTPoison.Error{}}
  end
end
