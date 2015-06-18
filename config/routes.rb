BlacklightEds::Engine.routes.draw do
  # EDS
  get 'articles', to: 'articles#index', as: :eds_articles
  get 'articles/:dbid/:an', to: 'articles#show', :constraints  => { :an => /[^\/]+/ }, as: :eds_detail
  get 'articles/:dbid/:an/fulltext/:fulltext_type', to: 'articles#fulltext', :constraints  => { :an => /[^\/]+/ }, as: :eds_fulltext
  get 'articles/switch/', to: 'articles#switch', as: :eds_switch
end


