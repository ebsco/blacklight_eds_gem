require 'blacklight'

module BlacklightEds::Articles
  extend ActiveSupport::Concern
  extend ActiveSupport::Autoload

  included do
    helper_method :search_action_url
  end

  def all
    # eds results
    api_query = generate_api_query params
    begin
      Timeout.timeout(30) do
        if eds_has_search_parameters?
          @results = eds_search api_query
          update_results_in_session @results
          eds_session[:api_query] = api_query
        end
      end
    rescue
      flash[:error] = t('eds.errors.connection')
      redirect_to request.path
    end

    if has_search_parameters?
      eds_session[:search_results_url] = request.url
    end

    # catalog search results
    (@response, @document_list) = get_search_results

    respond_to do |format|
      format.html { preferred_view }
      format.rss  { render :layout => false }
      format.atom { render :layout => false }
      format.json do
        render json: render_search_results_as_json
      end

      additional_response_formats(format)
      document_export_formats(format)
    end
  end

  def index
    api_query = generate_api_query params

    if eds_has_search_parameters?
      begin
        Timeout.timeout(30) do
          # to test, add sleep(30) here
          @results = eds_search api_query
          update_results_in_session @results
          eds_session[:api_query] = api_query
        end
      rescue
        flash[:error] = t('eds.errors.connection')
        redirect_to request.path
      end
    else
      if !params[:f].blank? or !params[:search_field].blank?
        flash.now[:error] = 'Please enter a search term in the search box '
      end
    end
  end

  def show
    recordArray = nil
    begin
      Timeout.timeout(30) do
        recordArray = eds_retrieve(params[:dbid].to_s,params[:an].to_s,termsToHighlight(params[:highlight]), "")

        if not eds_session.has_key? :results and eds_session.has_key? :api_query
          @results = eds_search eds_session[:api_query]
        end

        if recordArray['Record'].present?
          @record = recordArray['Record']
        end

        respond_to do |format|
          format.html
        end
      end
    rescue
      flash[:error] = t('eds.errors.connection')
      redirect_to search_action_url
    end
  end

  def fulltext
    if params[:fulltext_type] and params[:fulltext_type].start_with? 'ebook'
      fulltext_type = params[:fulltext_type]
    else
      fulltext_type = ''
    end

    recordArray = nil

    begin
      Timeout.timeout(30) do
        recordArray = eds_retrieve(params[:dbid].to_s,params[:an].to_s,termsToHighlight(params[:highlight]), fulltext_type)
        if recordArray['Record'].present?
          record = recordArray['Record']
        end
        fulltext_links = eds_fulltext_links(record, params[:fulltext_type])
        if fulltext_links.empty?
          flash.now[:error] = 'Full text not found for this item'
        else
          redirect_to eds_fulltext_links(record, params[:fulltext_type])[0]['Url']
        end
      end
    rescue
      flash.now[:error] = t('eds.errors.connection')
      redirect_to search_action_url
    end
  end

  def switch
    # check to see if the user is navigating to a record that was not included in the current page of results
    # if so, run a new search API call, getting the appropriate page of results
    next_id = params[:resultId].to_i
    if next_id > (params[:pagenumber].to_i * params[:resultsperpage].to_i)
      next_page = params[:pagenumber].to_i + 1
      new_params = params.dup
      new_params[:eds_action] = "GoToPage(" + next_page.to_s + ")"
    elsif next_id < (((params[:pagenumber].to_i - 1) * params[:resultsperpage].to_i) + 1)
      next_page = params[:pagenumber].to_i - 1
      new_params = params.dup
      new_params[:eds_action] = "GoToPage(" + next_page.to_s + ")"
    else
      next_page = params[:pagenumber].to_i
    end

    begin
      Timeout.timeout(30) do
        if new_params.present?
          api_query = generate_api_query(new_params)
          @results = eds_search api_query

          update_results_in_session @results
          eds_session[:api_query] = api_query
        end

        record_index = next_id.to_i - (next_page - 1) * params[:resultsperpage].to_i - 1
        next_record = eds_session[:results][record_index]

        next_an = next_record[0]
        next_dbid = next_record[1]
        next_highlight = params[:q]

        next_params = {dbid: next_dbid, an: next_an, resultId: next_id.to_s, hightlight: next_highlight}

        redirect_to path_for_eds_article dbid: next_dbid, an: next_an, resultId: next_id.to_s, hightlight: next_highlight
      end
    rescue
      flash.now[:error] = t('eds.errors.connection')
      redirect_to search_action_url
    end

  end

  def search_action_url(*args)
    eds_articles_url *args
  end

end
