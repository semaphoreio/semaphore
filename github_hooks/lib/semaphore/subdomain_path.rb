module Semaphore
  class SubdomainPath
    def call(subdomain, path = "", query = "")
      uri = base_uri

      uri.tap { |u|
        u.host = [subdomain, host_without_subdomain(base_uri)].join(".")
        u.path = path
        u.query = query if query.present?
      }.to_s
    end

    def ensure_safe_url(url, safe_url)
      if safe_url?(url)
        URI(url).tap { |u|
          u.scheme = "https"
        }.to_s
      else
        safe_url
      end
    end

    private

    def safe_url?(url)
      host_without_subdomain(URI(url)) == host_without_subdomain(base_uri)
    rescue NoMethodError
      false
    end

    def host_without_subdomain(uri)
      uri.host.split(".").keep_if.with_index { |_, k| k > 0 }.join(".")
    end

    def base_uri
      URI(App.base_url)
    end
  end
end
