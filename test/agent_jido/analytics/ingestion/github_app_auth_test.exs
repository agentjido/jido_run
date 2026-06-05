defmodule AgentJido.Analytics.Ingestion.GitHubAppAuthTest do
  use ExUnit.Case, async: true

  alias AgentJido.Analytics.Ingestion.GitHubAppAuth

  test "configured? accepts a complete GitHub App config" do
    assert GitHubAppAuth.configured?(
             github_app_id: "3971655",
             github_app_installation_id: "138216290",
             github_app_private_key: private_key_pem()
           )
  end

  test "configured? rejects incomplete GitHub App config" do
    refute GitHubAppAuth.configured?(github_app_id: "3971655")
  end

  test "app_jwt signs a GitHub App JWT" do
    assert {:ok, jwt} =
             GitHubAppAuth.app_jwt(
               github_app_id: "3971655",
               github_app_installation_id: "138216290",
               github_app_private_key: private_key_pem()
             )

    assert [_header, _payload, _signature] = String.split(jwt, ".")
  end

  defp private_key_pem do
    private_key = :public_key.generate_key({:rsa, 2048, 65_537})

    :RSAPrivateKey
    |> :public_key.pem_entry_encode(private_key)
    |> List.wrap()
    |> :public_key.pem_encode()
    |> to_string()
  end
end
