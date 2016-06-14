require 'ebsco-discovery-service-api'
require_dependency "blacklight_eds/application_controller"

class BlacklightEds::ArticlesController < BlacklightEds::ApplicationController
  include Blacklight::Marc::Catalog
  include Blacklight::Catalog
  include BlacklightEds::Articles
  include Blacklight::Catalog::SearchContext

  copy_blacklight_config_from CatalogController

  helper_method :search_action_url
  helper_method :path_for_eds_article

  before_filter :current_search_session, only: [:all, :index, :advanced]

  # to override any method in this class, create a new module, and include it in the extended controller class
end
