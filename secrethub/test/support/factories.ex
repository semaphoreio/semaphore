defmodule Support.Factories do
  def status_ok do
    InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
  end

  def status_not_ok(message \\ "") do
    InternalApi.ResponseStatus.new(
      code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
      message: message
    )
  end
end
