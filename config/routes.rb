BlacklightEds::Engine.routes.draw do
  # EDS
  get 'articles', to: 'articles#index'
  get 'articles/:dbid/:an', to: 'articles#detail', :constraints  => { :an => /[^\/]+/ }, as: 'eds_detail'
  get 'articles/:dbid/:an/fulltext' => 'articles#fulltext', :constraints  => { :an => /[^\/]+/ }
  get 'articles/switch/' => 'articles#switch'
end


