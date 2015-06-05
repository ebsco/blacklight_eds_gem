module BlacklightEds::ArticlesSearchContext
  extend ActiveSupport::Concern

  included do
    helper_method :eds_session
  end

  def eds_session
    session[:eds] ||= {}
  end
end