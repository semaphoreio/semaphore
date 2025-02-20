defmodule Rbac.SessionTest do
  use ExUnit.Case, async: true

  describe "serialize_into_session" do
    test "serialize user into session" do
      user = %Rbac.FrontRepo.User{id: "98b29afb-2450-426b-b5b3-8ef55b3719e1", salt: "pepper"}

      assert {"warden.user.user.key", [["98b29afb-2450-426b-b5b3-8ef55b3719e1"], "pepper"]} =
               Rbac.Session.serialize_into_session(user)
    end
  end

  describe "decrypt_cookie" do
    test "decrypt old rails cookie" do
      cookie =
        "dUlpakFCOG1xU3VNZ0M3QTRZOXZJK2g4MEE1WDZlNXZNS2djQnZQOXZUQk4xdXdmakhUSmtCZFgvRitWdk84Y2pCbXBCMmtxNnY0VG9udkRiV25UaGQ3VVIvNUtDRXJrY0ZmdExYakFwZlNqUGtPUnpjR2lrRGlzTzNpdDdKYjVJTzVYbTg4dWtOSGtBdEVDOGpnZW9PQ1lyZk1CRHdKWG53TFowTGhjbzRSNU9TR3o1YUFvMjdYeVhselNZOGppVnFlU2FudTdKMUdtbDN5Mlhqc2w4Rm1iVG84SkxvZjg3MUJMeDRnUjRRaDdRWDZOUjJpcWFpc3RpNnV3OElkby0tWmVhSFB4RFRkd3NTZFB2NFdlMG9rZz09--289961c6c56fa3c5d33b8fa0abb2d65e737bbd2d"

      assert %{
               "id_provider" => "GITHUB",
               "ip_address" => "127.0.0.1",
               "user_agent" => "Mozilla/5.0",
               "warden.user.user.key" => [["eb9d758d-1f4b-43a2-be67-7bf5768251f9"], "pepper"]
             } = Rbac.Session.decrypt_cookie(cookie)
    end

    test "decrypt new rails cookie" do
      cookie =
        "ay9kRC96dVhFQ3lQY3lFUnN2cncwTHFxZGxIdUFncTgzWEwzSEw3SlVYUmsvNFlXL2ZZMFJOV1IyVTF6YisvT3VDNUlHcm1aLzFvdm95Z1FpcWNFRDV0c0N0R0FCa2pOVWxEMDlhd2pWQXV1aVZJbnorRlVuSk9heTA2MWp1L3B4OWdCako4a1NiempxRGxnZHB3NlZxdHdsVWY3cTI5U0xXdExKd0h4WVlmOUpYSXEvbW5VNlRBQlgydjEvMUpQWnpkRGQ1ajYveGl1cTNhU2xLdll5TUxNTXZBRHFoSk1nZDJIVVJ3ZlRPYXVDSVJ2bVJ4eVV2NkNPU0FXTHJDaVM3ZUdCcVpvOEM1Ylk1dVJENFdWbDdHT0IwY0llK1diL0J3SEs4aU04enpOUTJVa0dOUUluRFlvbW55OUtFdTFJdlhLbXFCYS9qUVoyajBuTis2OVhOdjV3ZnFhYW1qQkdHRmlTMXphS002VngxMk1Wc3kwN3BYWExsalRsak40LS16UkZBUnowNWJyNDZGV3c0dWtFQzhBPT0%3D--0290ad6eb41475f46ffbe5d3b4f7414547ddeddd"

      assert %{
               "id_provider" => "GITHUB",
               "ip_address" => "127.0.0.1",
               "user_agent" => "Mozilla/5.0",
               "warden.user.user.key" => [["98b29afb-2450-426b-b5b3-8ef55b3719e1"], "pepper"]
             } = Rbac.Session.decrypt_cookie(cookie)
    end
  end

  describe "encrypt_cookie" do
    test "encrypted cookie can be decrypted" do
      cookie = %{
        "id_provider" => "GITHUB",
        "ip_address" => "127.0.0.1",
        "user_agent" => "Mozilla/5.0",
        "warden.user.user.key" => [["98b29afb-2450-426b-b5b3-8ef55b3719e1"], "pepper"]
      }

      assert Rbac.Session.encrypt_cookie(cookie) |> Rbac.Session.decrypt_cookie() == cookie
    end
  end
end
