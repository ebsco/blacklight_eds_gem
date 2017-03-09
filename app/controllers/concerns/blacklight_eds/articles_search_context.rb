module BlacklightEds::ArticlesSearchContext
  extend ActiveSupport::Concern

  included do
    helper_method :eds_session
  end

  def eds_session
    # prevent eds_session[:info] from overloading the session by removing it
    session[:eds].delete :info
    session[:eds] ||= {}
  end
end