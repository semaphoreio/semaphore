# rubocop:disable all

class Policy::NjsScan < Policy
  def test
    @output = `njsscan -w .`
    $?.success?
  end

  def reason
    @output
  end

  def dependencies
    [
      {
        name: "pip3",
        install: Proc.new do
          `sudo apt-get update && sudo apt-get -y install python3-pip`
          $?.exitstatus
        end
      },
      {
        name: "njsscan",
        install: Proc.new do
          `pip3 install --upgrade njsscan`
          $?.exitstatus
        end
      }
    ]
  end
end
