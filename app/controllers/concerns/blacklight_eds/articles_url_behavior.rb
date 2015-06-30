module BlacklightEds::ArticlesUrlBehavior
  extend ActiveSupport::Concern

  included do
    helper_method :search_action_url, :path_for_eds_article
  end

  def search_action_url(*args)
    eds_articles_url *args
  end

  def path_for_eds_article(*args)
    eds_detail_path *args
  end
end