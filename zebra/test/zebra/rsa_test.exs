defmodule Zebra.RSATest do
  use Zebra.DataCase

  test "generate" do
    rsa = Zebra.RSA.generate()

    assert rsa.public_key =~ ~r/ssh-rsa .*/s
    assert rsa.private_key =~ ~r/-----BEGIN RSA PRIVATE KEY-----.*-----END RSA PRIVATE KEY-----/s
  end

  test "repeated generation" do
    1..100
    |> Enum.each(fn _ ->
      Zebra.RSA.generate()
    end)
  end
end
