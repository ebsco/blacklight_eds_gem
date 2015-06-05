module BlacklightEds
  class ApplicationController < ::ApplicationController
    include BlacklightEds::ArticlesControllerBehavior
    include BlacklightEds::ArticlesSearchContext

    def search_action_url(*args)
      articles_url *args
    end

  end
end