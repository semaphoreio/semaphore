defmodule PipelinesAPI.Loghub2Client.Test do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.Loghub2Client

  @job_id UUID.uuid4()
  @token "asdasfasd"

  setup do
    Support.Stubs.reset()
  end

  describe ".generate_token" do
    test "successful response" do
      GrpcMock.stub(Loghub2Mock, :generate_token, fn _, _ ->
        %InternalApi.Loghub2.GenerateTokenResponse{
          token: @token,
          type: InternalApi.Loghub2.TokenType.value(:PULL)
        }
      end)

      assert {:ok, token} = Loghub2Client.generate_token(@job_id)
      assert token == @token
    end

    test "failure response" do
      GrpcMock.stub(Loghub2Mock, :generate_token, fn _, _ ->
        raise "oops"
      end)

      assert {:error, {:internal, "Internal error"}} = Loghub2Client.generate_token(@job_id)
    end
  end
end
