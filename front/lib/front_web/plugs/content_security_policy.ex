defmodule FrontWeb.Plug.ContentSecurityPolicy do
  @behaviour Plug

  #
  # To configure the Content-Security-Policy header,
  # we need to use values that are only available during runtime,
  # so we can't use the PlugContentSecurityPolicy plug directly.
  #
  # This plug is a wrapper around the PlugContentSecurityPolicy plug,
  # which uses runtime configuration to configure
  # and call the PlugContentSecurityPolicy plug.
  #
  # NOTE: the System.get_env/1 calls, must be inside the call/2 function,
  # since :init_mode is generally set to :compile in a MIX_ENV=prod context
  #

  @impl true
  def init(_opts) do
    []
  end

  @impl true
  def call(conn, _opts) do
    opts = PlugContentSecurityPolicy.init(options())

    PlugContentSecurityPolicy.call(conn, opts)
  end

  defp options do
    base_domain = System.get_env("BASE_DOMAIN")

    [
      nonces_for: [:script_src],
      report_only: Application.get_env(:front, :environment) in [:dev, :test],
      directives: %{
        base_uri: ~w('self'),
        connect_src: connect_src(),
        default_src: ~w('none'),
        form_action:
          ~w('self' semaphoreci.zendesk.com bitbucket.org github.com gitlab.com) ++
            ["*.#{base_domain}"],
        media_src: ~w(beacon-v2.helpscout.net),
        child_src: ~w('self'),
        font_src: ~w('self' beacon-v2.helpscout.net fonts.gstatic.com cdn.jsdelivr.net),
        img_src:
          ~w(data: 'self' *.posthog.com static.zdassets.com *.zendesk.com gravatar.com *.gravatar.com *.wp.com *.githubusercontent.com d12wqas9hcki3z.cloudfront.net bitbucket.org github.com gitlab.com beacon-v2.helpscout.net d33v4339jhl8k0.cloudfront.net chatapi-prod.s3.amazonaws.com/ bitbucket-assetroot.s3.amazonaws.com ui-avatars.com *.atl-paas.net *.sitesearch360.com storage.googleapis.com) ++
            ["docs.#{base_domain}"],
        script_src:
          ~w(https: 'self' 'strict-dynamic' *.posthog.com static.zdassets.com beacon-v2.helpscout.net d12wqas9hcki3z.cloudfront.net d33v4339jhl8k0.cloudfront.net *.sitesearch360.com www.googletagmanager.com cdn.jsdeliver.net),
        style_src:
          ~w('self' 'unsafe-inline' *.posthog.com fonts.gstatic.com fonts.googleapis.com cdnjs.cloudflare.com beacon-v2.helpscout.net cdn.jsdelivr.net),
        frame_src: ~w('self' beacon-v2.helpscout.net),
        object_src: ~w(beacon-v2.helpscout.net)
      }
    ]
  end

  defp connect_src do
    [
      "'self'",
      "*.#{System.get_env("BASE_DOMAIN")}",
      "wss://*.posthog.com",
      "https://*.posthog.com",
      "wss://api.smooch.io",
      "api.smooch.io",
      "semaphoreci.zendesk.com",
      "ekr.zdassets.com",
      "beaconapi.helpscout.net",
      "chatapi.helpscout.net",
      "storage.googleapis.com",
      "d3hb14vkzrxvla.cloudfront.net",
      "wss://*.pusher.com",
      "*.sumologic.com",
      "www.google-analytics.com",
      "*.sitesearch360.com"
    ] ++ additional_connect_domains()
  end

  defp additional_connect_domains do
    Application.get_env(:front, :csp_additional_connect_domains, [])
  end
end
