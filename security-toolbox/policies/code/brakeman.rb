# rubocop:disable all

class Policy::Brakeman < Policy
  def initialize(args)
    super(args)
  end

  def test
    command = [
      "brakeman",
      "-A",
      "--color",
      "-w3"
    ]

    @output = `#{command.join(" ")}`
    $?.success?
  end

  def reason
    @output
  end

  def dependencies
    [
      {
        name: "brakeman",
        install: Proc.new do
          command = [
            "gem install brakeman --no-doc"
          ]

          `#{command.join(" && ")}`
          $?.exitstatus
        end
      }
    ]
  end
end
