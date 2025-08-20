class PresenterBase

  def translate(*args, &block)
    I18n.t(*args, &block)
  end

  alias_method :t, :translate

  def localize(*args, &block)
    I18n.l(*args, &block)
  end

  alias_method :l, :localize

  def routes
    Rails.application.routes.url_helpers
  end

  alias_method :r, :routes

  delegate :helpers, to: ApplicationController

  alias_method :h, :helpers

end
