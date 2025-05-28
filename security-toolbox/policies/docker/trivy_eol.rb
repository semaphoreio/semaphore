# rubocop:disable all

class Policy::TrivyEOL < Policy
  def initialize(args)
    super(args)

    if !args.key?(:image)
      raise "Image is required"
    end

    @image = args[:image]
    @ignore_policy = args[:ignore_policy] || nil
    @skip_files = args[:skip_files].to_s.split(",") || []
    @skip_dirs = args[:skip_dirs].to_s.split(",") || []
  end

  def test
    # Check if the report was generated
    if File.exist?("out/results.json")
      require 'json'

      report = JSON.parse(File.read("out/results.json"))

      # Check for EOSL flag in metadata
      eol_detected = report.dig("Metadata", "OS", "EOSL") == true
      os_name = report.dig("Metadata", "OS", "Name") || "unknown"
      os_family = report.dig("Metadata", "OS", "Family") || "unknown"


      if eol_detected
        # Optionally add it as a custom Result entry to match Trivy's structure
        eol_result = {
          "Target" => "OS End of Life Check",
          "Class" => "custom",
          "Type" => "dockerfile",
          "Vulnerabilities" => [{
            "VulnerabilityID" => "OS-EOL-001",
            "Title" => "Operating System End of Life",
            "PkgName" => "#{os_family}",
            "InstalledVersion" => "#{os_name}",
            "Description" => "The operating system #{os_family} #{os_name} has reached end of life and no longer receives security updates",
            "Severity" => "HIGH",
            "References" => [
              "https://endoflife.date/#{os_family}"
            ]
          }]
        }

        # Add to Results array if you want it to appear alongside other findings
        report["Results"] ||= []
        report["Results"] << eol_result
      end

      # Write the extended report back
      File.write("out/results.json", JSON.pretty_generate(report))

      # Set output and return status
      if eol_detected
        @output = "FAIL: #{os_family} #{os_name} is End of Life (EOL)"
        return false
      else
        @output = "PASS: Operating system is supported"
        return true
      end
    else
      @output = "ERROR: Failed to find results.json"
      return false
    end
  rescue => e
    @output = "ERROR: #{e.message}"
    return false
  end

  def reason
    @output
  end

  def dependencies
    [
      {
        name: "trivy",
        install: Proc.new do
          `curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin`
          $?.exitstatus
        end
      }
    ]
  end
end
