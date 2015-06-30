module BlacklightEds
  class ApplicationController < ::ApplicationController
    include BlacklightEds::ArticlesControllerBehavior
    include BlacklightEds::ArticlesSearchContext
    include BlacklightEds::ArticlesUrlBehavior

  end
end