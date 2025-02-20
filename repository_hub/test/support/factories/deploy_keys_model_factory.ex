defmodule RepositoryHub.DeployKeysModelFactory do
  import RepositoryHub.Toolkit

  @default_public_key ~S"""
  ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwO7Ih2nDe+tVQwHWyskBGU2hx6jBRF4WsSop9EyQghCTe+StU+ywmZFIEBZGSd/WYmj+J0lPaWV9ipJZ6TtPRI1oIJeDBE1ZzoLF4wC/5n302SsO+TT8oCHFGwMMTP3TCAdRrBHf4XVPY9BRSi67+Mvl/2Lvq1/CfVKohXZGwgHxbmvbCbGPXLDcuvs9r02CTyerjKUtJyv2t3+1CJSDDxO/CNaHN7CP0clgtesXX7cvr8WcGRecAr/3ZxKbwVEvDk4paElRMmpzf28VUXhOJ8Tn3KZxvDHeE/alsXYhP/QmoNEhrKitki5ccITufnywQXeLVcZch6Gkn8PLaHuUV
  """

  @default_private_key ~S"""
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABChIJMRPi
  qaMxUU6vn09bmNAAAAEAAAAAEAAAEXAAAAB3NzaC1yc2EAAAADAQABAAABAQCwO7Ih2nDe
  +tVQwHWyskBGU2hx6jBRF4WsSop9EyQghCTe+StU+ywmZFIEBZGSd/WYmj+J0lPaWV9ipJ
  Z6TtPRI1oIJeDBE1ZzoLF4wC/5n302SsO+TT8oCHFGwMMTP3TCAdRrBHf4XVPY9BRSi67+
  Mvl/2Lvq1/CfVKohXZGwgHxbmvbCbGPXLDcuvs9r02CTyerjKUtJyv2t3+1CJSDDxO/CNa
  HN7CP0clgtesXX7cvr8WcGRecAr/3ZxKbwVEvDk4paElRMmpzf28VUXhOJ8Tn3KZxvDHeE
  /alsXYhP/QmoNEhrKitki5ccITufnywQXeLVcZch6Gkn8PLaHuUVAAAD0EMoSzxIiUj4P9
  1VsPdhXopK8EY/CbsnEwRBalviAqCn8zozfS9CiMHu5+XdvuvSln3iEZdZwf6FxTdpw7lS
  dSM543+ijury2cmUE3wIC08tFKt+UZPqv9U13mXIDCFnhbvmZJQ9ofMQmo+LkvPRbxLUNN
  E3A2O+k6W00W7RoGRSkP/2BaGGPRX4dIEhSzBer2ECgZ7s0pWlRe+uxjNTeC9D2Y9yxV/S
  IIazi5Wylyk8RgcYJRCXk+xVW+wt8m9tN9fDtDJeCQHiT26/JefcYaoOS0oPqHtBOIufYV
  d/r05CzKdRVJrnovvXgh4PqIaq0SP9wAfs9ySzQZJORlANulwyRGeXiNUuH0/PCf7xesuV
  q3lHeDbIqI36HMlwNq9fCJmE2Pmh07MWQzVgkdg+CNhV9nusFkpp8Dfa1XvEbxRK83UZFj
  03Lk9DxZZSy+tfYYIvtIS0EtIkAlYF7mIdFHO8N59OaPKz05k9kC3Hz9tsgofZNFqdIeMH
  NK1ZAAKvWDXoK94/jhmVnT/Jfd3m7AdIBVUcTxkM0Xzn6uo9gX0g15mlCviybfsawGbCph
  DxjBNy2hungWSxdL4fsMmouVC3HFGY5BYqAY2UtqHIyEg3jwJkz9L73F4W8DQLEsvk3pQd
  2bwmZ3Hvpnmk+3TekM87TN7CcsBywgKnVMM4yQRyZkk6tdVSNSGpl1Fb+IH6lNQqq/Wpn/
  G3W8GK+8/XetUsYcHyTbNEt4zj7yMnNqMq7UNkfKXjEMR6+pvTJxjX1s4ed2m3dB0pBH2y
  Y55Nk2AFchcUDeN6X0FpalfehDPPsrt3I/mItYF+7MyvtPiXYABTPBdjKwvPOpqxyL7yLq
  WrgPhQ6jiTaU9hbnRFqgNIhaZrVM6pmcAz33NsRFGCgqX8QeRzWMxRbLf3fZNw0UdPAdMF
  4mnbfQBXk3K7mOJ57ZGL6fi8GRVNvaqTJMe4rQs0UZD2oL9q6iBKHFYlV/5VmH5/e/haJe
  pRIEIGPWnp/R+RDSyjdWpBypaV9Zrydu6qNHHzhdxFtL48qPVRvUQ7J3YUTO+btqh5aAFU
  NXCBW+UNGgGcabt4PzLHa75ZbHMIOkyESgUsUzikNdhx9AAioPmnV4Te/88ePwk0ZuYhw9
  UGn8Tb2zmKp77rYwgXT8LPUpaN+a9ZAtWIRlpksAeawp9sjqCXD898rYEmPAznN6Sw/dr6
  IMQkS1+UTDpR0dJRVlPILopX2aIHZV8g3UiKZP5t6k3jVu7aRKjjeOWLtl8IYOQhXc0JzN
  0Azr1UwbqDuBepYQlpHzTppp4Xe74=
  -----END OPENSSH PRIVATE KEY-----
  """

  def create_deploy_key(params \\ []) do
    project_id = Ecto.UUID.generate()
    repository_id = Ecto.UUID.generate()

    {:ok, private_key_enc} =
      RepositoryHub.Encryptor.encrypt(RepositoryHub.DeployKeyEncryptor, @default_private_key, "semaphore-#{project_id}")

    {:ok, _} =
      params
      |> with_defaults(
        project_id: project_id,
        public_key: @default_public_key,
        private_key_enc: private_key_enc,
        repository_id: repository_id,
        remote_id: 1
      )
      |> Enum.into(%{})
      |> RepositoryHub.Model.DeployKeyQuery.insert()
  end
end
