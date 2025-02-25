# rubocop:disable all

class Policy::GemLicenses < Policy
  def initialize(args)
    super(args)
    @whitelist_licenses_for_packages = args[:whitelist_licenses_for_packages] || nil
  end

  def test
    @licenses_check_path = File.join(File.dirname(__FILE__), "licenses/check_ruby.sh")
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
        name: "ruby",
        install: Proc.new do
          `sudo apt-get update && sudo apt-get -y install ruby`
          $?.exitstatus
        end
      }
    ]
  end
end
