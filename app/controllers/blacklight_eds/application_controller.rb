module BlacklightEds
  class ApplicationController < ::ApplicationController
    include BlacklightEds::ArticlesControllerBehavior
    include BlacklightEds::ArticlesSearchContext


  end
end