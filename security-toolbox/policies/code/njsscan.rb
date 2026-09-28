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
          # PEP 668 blocks plain pip installs; sudo also puts the entry point in /usr/local/bin.
          `sudo pip3 install --break-system-packages njsscan==1.0.0`
          $?.exitstatus
        end
      }
    ]
  end
end
