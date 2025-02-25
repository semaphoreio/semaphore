# rubocop:disable all

class Policy::MixAudit < Policy
  def initialize(args)
    super(args)
    @ignore_packages = args[:ignore_packages] || nil
  end

  def test
    command = [
      "~/.mix/escripts/mix_audit"
    ]

    if @ignore_packages != nil
      command << "--ignore-package-names #{@ignore_packages}"
    end

    @output = `#{command.join(" ")}`
    $?.success?
  end

  def reason
    @output
  end

  def dependencies
    [
      {
        name: "erl",
        install: Proc.new do
          `sudo apt-get update && sudo apt-get -y install erlang`
          $?.exitstatus
        end
      },
      {
        name: "elixir",
        install: Proc.new do
          `sudo apt-get update && sudo apt-get -y install elixir`
          $?.exitstatus
        end
      },
      {
        name: "~/.mix/escripts/mix_audit",
        install: Proc.new do
          command = [
            "mix local.hex --force",
            "mix local.rebar --force",
            "mix escript.install hex mix_audit --force"
          ]

          `#{command.join(" && ")}`
          $?.exitstatus
        end
      }
    ]
  end
end
