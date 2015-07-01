module BlacklightEds::ArticlesUrlBehavior
  extend ActiveSupport::Concern

  included do
    helper_method :path_for_eds_article
  end

  def path_for_eds_article(*args)
    eds_detail_path *args
  end
end