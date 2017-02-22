require 'date'

module BlacklightEds::ArticlesControllerBehavior
  extend ActiveSupport::Concern

  included do
    helper_method :eds_num_limiters, :eds_info, :eds_fulltext_links, :eds_has_search_parameters?
  end

  ADVANCED_KEYS = { author: 'AU', title: 'TI', subject: 'SU', journal: 'SO', abstract: 'AB', alltext: 'TX' }

  def html_unescape(text)
    return CGI.unescape(text)
  end

  def need_to_reconnect?(profile)
    return ( (not session.has_key? :eds_connection) or                  # If there is no existing connection
        ( eds_session[:profile] != profile) or                      # Or we're changing profiles
        ( eds_user_signed_in? and eds_session[:user] == 'guest') or     # Or the user is already logged in
        ( not eds_user_signed_in? and eds_session[:user] != 'guest') and   # Or the user is logged out
            not flash[:error] == t('eds.errors.connection') and
            params[:search_scope] != 'catalog')
  end

  # Returns the connection object when called
  def eds_connection
    profile =  params[:eds_profile] || params[:campus] || 'default'
    # Only create a new connection under the following circumstances:
    if need_to_reconnect? profile
      begin
        Timeout.timeout(30) do
          # creates EDS API connection object, initializing it with application login credentials
          connection = EDSApi::ConnectionHandler.new(2)
          account = eds_profile profile
          is_guest = eds_user_signed_in? ? 'n' : 'y'
          connection.uid_init(account['username'], account['password'], account['profile'], is_guest)
          Rails.cache.delete_matched('eds_auth_token/*') # clean up the cache
          eds_session.delete :session_key
          eds_session[:profile] = profile
          session[:eds_connection] = connection
        end
      rescue Exception, RuntimeError => e
        logger.tagged('EDS') {
          logger.error e
        }
        flash[:error] = t('eds.errors.connection')
      end
    end
    session[:eds_connection]
  end

  # Returns a profile. If the profile param is null, return the first profile
  def eds_profile profile=nil
    profiles = Rails.application.config.eds_profiles
    profiles.fetch(profile, profiles.values[0])
  end

  # Returns EDS auth_token. It's stored in Rails Low Level Cache, and expires in every 30 minutes
  def eds_auth_token
    cache_key = eds_user_signed_in? ? 'eds_auth_token/user' : 'eds_auth_token/guest'
    auth_token = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      eds_connection.uid_authenticate :json
      eds_connection.show_auth_token
    end
    logger.tagged('EDS') {
      logger.debug 'eds auth token: ' << auth_token
    }
    auth_token
  end

  def eds_session_key
    if eds_user_signed_in?
      if eds_session[:user] != eds_current_user.id
        eds_session[:user] = eds_current_user.id
        eds_session[:session_key] = eds_connection.create_session eds_auth_token
      end
    else
      if eds_session[:user] != 'guest'
        eds_session[:user] = 'guest'
        eds_session[:session_key] = eds_connection.create_session eds_auth_token
      end
    end
    eds_session[:session_key] ||= eds_connection.create_session eds_auth_token
    logger.tagged('EDS') {
      logger.debug 'eds session_key: ' << eds_session[:session_key]
    }
    eds_session[:session_key]
  end

  def eds_info
    eds_session[:info] ||= eds_connection.info(eds_session_key, eds_auth_token, :json).to_hash
  end

  def eds_num_limiters
    eds_session[:num_limiters] = eds_info.fetch('AvailableSearchCriteria', {}).fetch('AvailableLimiters', nil)
                                     .count{|limiter| limiter['Type'] == 'select'}
  end

  # after basic functions like SEARCH, INFO, and RETRIEVE, check to make sure a new session token wasn't generated
  # if it was, use the new session key from here on out
  def check_session_currency
    if eds_connection.show_session_token != eds_session_key  # reset values. They'll be populated next time called
      [:session_key, :info, :num_limiters].each { |k| eds_session.delete(k) }
    end
  end

  # generates parameters for the API call given URL parameters
  # options is usually the params hash
  # this function strips out unneeded parameters and reformats them to form a string that the API accepts as input
  def generate_api_query(options)
    unless options.has_key? 'resultsperpage'
      # set number of results per page using the blacklight_config if available
      if blacklight_config.present? and blacklight_config.has_key? :default_solr_params
        if blacklight_config[:default_solr_params].has_key? :rows
          options['resultsperpage'] = blacklight_config[:default_solr_params][:rows]
        end
      end
    end

    #filter to make sure the only parameters put into the API query are those that are expected by the API
    edsKeys = ["eds_action", "q", "facetfilter[]", "facetfilter", "sort", "includefacets", "searchmode", "view", "resultsperpage", "sort", "pagenumber", "highlight", "limiter", "limiter[]"]
    eds_options = options.select {|key| edsKeys.include?(key) or key.start_with? 'query-' }
    #rename parameters to expected names
    #action and query-1 were renamed due to Rails and Blacklight conventions respectively
    eds_options['action'] = eds_options.delete 'eds_action'
    if eds_options.has_key? 'q'
      eds_options['query-1'] = query_fragment 'AND', options['search_field'], eds_options.delete('q').gsub(/[,:]/, ' ')
    end

    searchquery = eds_options.permit!.to_h.to_query
    # , : ( ) - decoding expected punctuation
    searchquery = searchquery.gsub('limiter%5B%5D', 'limiter')
                      .gsub('facetfilter%5B%5D', 'facetfilter')
                      .gsub('%28', '(')
                      .gsub('%3A', ':')
                      .gsub('%29', ')')
                      .gsub('%23', ',')
    searchquery
  end

  def advanced_generate_api_query(options)
    query_options = options.select { |key, val| ADVANCED_KEYS.include? key.to_sym and not val.blank?}
    search_query = {}
    query_options.each_with_index { |pair, i|
      search_query["query-#{i+1}"] = query_fragment options['op'] || 'AND', pair[0], pair[1].to_s.gsub(/[,:]/, ' ')
    }
    # publication dates
    start_date = Date.parse(options['publication_date_start']).strftime('%Y%m%d') rescue nil
    end_date = Date.parse(options['publication_date_end']).strftime('%Y%m31') rescue nil
    search_query["query-#{search_query.size+1}"] = "AND,DT:#{start_date}-#{end_date}" if !start_date.blank? and !end_date.blank?
    search_query['sort'] = options['sort'] unless options['sort'].blank?
    search_query.to_query
  end

  def query_fragment(op='AND', field='', term)
    field_code = ADVANCED_KEYS.fetch( (field||'').to_sym, '')
    field_code.blank? ? "#{op},#{term}" : "#{op},#{field_code}:#{term}"
  end

  # main search function.  accepts string to be tacked on to API endpoint URL
  def eds_search(apiquery)
    #eds_session[:debugNotes << "<p>API QUERY SENT: " << apiquery.to_s << "</p>"

    # force turn off highlight to fix eds gem bug
    apiquery.gsub!("highlight=y", "highlight=n")

    results = eds_connection.search(apiquery, eds_session_key, eds_auth_token, :json).to_hash

    #update session_key if new one was generated in the call
    check_session_currency
    results
  end

  def eds_retrieve(dbid, an, highlight = "", ebookpreferredformat="")
    #eds_session[:debugNotes << "HIGHLIGHTBEFORE:" << highlight.to_s
    highlight.downcase!
    highlight.gsub! ',and,', ','
    highlight.gsub! ',or,', ','
    highlight.gsub! ',not,', ','
    #eds_session[:debugNotes << "HIGHLIGHTAFTER: " << highlight.to_s
    record = eds_connection.retrieve(dbid, an, highlight, ebookpreferredformat, eds_session_key, eds_auth_token, :json).to_hash
    #eds_session[:debugNotes << "RECORD: " << record.to_s
    #update session_key if new one was generated in the call
    check_session_currency

    record
  end

  def termsToHighlight(terms = "")
    if terms.present?
      words = terms.split(/\W+/)
      return words.join(",").to_s
    else
      return ""
    end
  end

  # helper function for iterating through results from
  def switch_link(params, qurl)

    # check to see if the user is navigating to a record that was not included in the current page of results
    # if so, run a new search API call, getting the appropriate page of results
    if params[:resultId].to_i > (params[:pagenumber].to_i * params[:resultsperpage].to_i)
      nextPage = params[:pagenumber].to_i + 1
      newParams = params
      newParams[:eds_action] = "GoToPage(" + nextPage.to_s + ")"
      options = generate_api_query(newParams)
      search(options)
    elsif params[:resultId].to_i < (((params[:pagenumber].to_i - 1) * params[:resultsperpage].to_i) + 1)
      nextPage = params[:pagenumber].to_i - 1
      newParams = params
      newParams[:eds_action] = "GoToPage(" + nextPage.to_s + ")"
      options = generate_api_query(newParams)
      search(options)
    end

    link = ""
    # generate the link for the target record
    if @results['SearchResult']['Data']['Records'].present?
      @results['SearchResult']['Data']['Records'].each do |result|
        nextId = show_resultid(result).to_s
        if nextId == params[:resultId].to_s
          nextAn = show_an(result).to_s
          nextDbId = show_dbid(result).to_s
          nextrId = params[:resultId].to_s
          nextHighlight = params[:q].to_s
          link = request.fullpath.split("/switch")[0].to_s + "/" + nextDbId.to_s + "/" + nextAn.to_s + "/?resultId=" + nextrId.to_s + "&highlight=" + nextHighlight.to_s
        end
      end
    end
    return link.to_s

  end

  def get_num_limiters(info)
    avai_limiters = info.fetch('AvailableSearchCriteria', {}).fetch('AvailableLimiters', nil)
    avai_limiters.count{|limiter| limiter['Type'] == 'select'}
  end

  ############
  # File / Token Handling / End User Auth
  ############

  def clear_session_key
    session.delete(:session_key)
  end

  def getAuthToken
    eds_connection.uid_authenticate(:json)
    eds_connection.show_auth_token
  end


  ############
  # Linking Utilities
  ############

  def eds_fulltext_links(result, types)
    result.fetch('FullText', {}).fetch('Links', []).select { |link|
      types.include? link['Type']
    }
  end

  ################
  # Debug Functions
  ################

  def show_query_string
    return @results['queryString']
  end

  def debugNotes
    return #eds_session[:debugNotes << "<h4>API Calls</h4>" << @connection.debug_notes
  end


  def eds_has_search_parameters?
    #!params[:q].blank? or !params[:f].blank? or !params[:search_field].blank?
    if params[:advanced]
      not params.select { |key, val| ADVANCED_KEYS.include?(key.to_sym) and not val.blank? }.empty?
    else
      not params[:q].blank?
    end
  end

  # preview and next ---------------------------------------

  def start_new_search_session?
    action_name == 'index'
  end

  def update_results_in_session results
    eds_session[:results] = results.fetch('SearchResult', {}).fetch('Data', {}).fetch('Records', []).map { |r|
      [r.fetch('Header', {}).fetch('An', nil), r.fetch('Header', {}).fetch('DbId', nil)]
    }
    eds_session[:query_string] = results.fetch('SearchRequestGet', {}).fetch('QueryString', nil)
    eds_session[:total_hits] = results.fetch('SearchResult', {}).fetch('Statistics', {}).fetch('TotalHits', -1)
  end

end
