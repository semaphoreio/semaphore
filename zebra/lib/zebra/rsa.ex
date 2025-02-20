defmodule Zebra.RSA do
  defstruct [:private_key, :public_key]

  def generate do
    # Generate a random string for storing the generation key pair.
    # We use random names in order to make sure the algorithm can work in
    # parallel without stepping on itself.
    name =
      :crypto.strong_rand_bytes(30)
      |> Base.encode64()
      |> Base.url_encode64(padding: false)

    # The private file is generated in <name> while the public part will be
    # stored in <name>.pub
    private_file = "/tmp/#{name}"
    public_file = "#{private_file}.pub"

    # Fail if the exit status is non-zero.
    {_, 0} =
      System.cmd("ssh-keygen", [
        # bit size, 2048 is safe til 2030. 4096 is slow.
        "-b",
        "2048",
        # RSA type.
        "-t",
        "rsa",
        # newer versions of ssh-keygen use the OPENSSH-specific format, we want the PEM one.
        "-m",
        "PEM",
        # create without passphrase
        "-N",
        "",
        # output file path
        "-f",
        private_file
      ])

    private_key = File.read!(private_file)
    public_key = File.read!(public_file)

    # make sure to not let garbage accumulate on a system
    File.rm!(private_file)
    File.rm!(public_file)

    # the public key consists of three parts, the type, key, and a comment.
    # here we drop the comment
    public_key =
      public_key
      |> String.split(" ")
      |> Enum.take(2)
      |> Enum.join(" ")

    %__MODULE__{private_key: private_key, public_key: public_key}
  end
end
