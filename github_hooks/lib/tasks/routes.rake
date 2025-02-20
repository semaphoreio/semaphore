namespace :app do
  class RouteWrapper < SimpleDelegator
    def url_helper
      name.to_s.present? ? "#{name}_path" : "(no_path_helper)"
    end

    def path
      super.spec.to_s.gsub("(.:format)", "")
    end

    def controller
      parts.include?(:controller) ? ":controller" : requirements[:controller]
    end

    def action
      parts.include?(:action) ? ":action" : requirements[:action]
    end

    def verb
      super.inspect.gsub("/^", "").gsub("$/", "")[0..6].rjust(6)
    end

    def display
      puts "\e[35m#{verb}\e[0m \e[33m#{path}\e[0m \e[34m#{controller}##{action}\e[0m #{url_helper}\e[0m"
    end
  end

  task :routes => :environment do
    Rails.application
         .routes
         .routes
         .map { |route| RouteWrapper.new(route) }
         .each(&:display)
  end
end
