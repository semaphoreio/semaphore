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
        name: "pipx",
        install: Proc.new do
          `sudo apt-get update && sudo apt-get -y install pipx`
          $?.exitstatus
        end
      },
      {
        name: "njsscan",
        install: Proc.new do
          # njsscan needs versions of packages the distribution also manages, and pip
          # cannot replace those - it refuses on a Python it does not own. pipx gives
          # njsscan its own environment; the bin dir puts the entry point on PATH.
          `sudo PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install njsscan==1.0.0`
          $?.exitstatus
        end
      }
    ]
  end
end
