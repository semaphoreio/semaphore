# rubocop:disable all

class Policy::MixLicenses < Policy
  def initialize(args)
    super(args)
    @whitelist_licenses_for_packages = args[:whitelist_licenses_for_packages] || nil
  end

  def test
    @licenses_check_path = File.join(File.dirname(__FILE__), "licenses/check_elixir.sh")
    command = [
      "bash #{@licenses_check_path}"
    ]

    if @whitelist_licenses_for_packages != nil
      command << "--whitelist-licenses-for-packages #{@whitelist_licenses_for_packages}"
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
        name: "~/.mix/archives/licensir-0.7.0",
        install: Proc.new do
          command = [
            "mix local.hex --force",
            "mix local.rebar --force",
            "mix archive.install hex licensir 0.7.0 --force"
          ]

          `#{command.join(" && ")}`
          $?.exitstatus
        end
      }
    ]
  end
end
