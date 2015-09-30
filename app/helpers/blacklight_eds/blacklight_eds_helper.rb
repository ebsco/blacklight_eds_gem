require 'htmlentities'
require 'addressable/uri'

module BlacklightEds::BlacklightEdsHelper

  # check to see if result has any facets.  crude, and I forget why I had to do a length check..
  def has_eds_facets?
    @results.fetch('SearchResult', {}).fetch('AvailableFacets', []).any?
  end

  # pulls <QueryString> from the results of the current search to serve as the baseURL for next request
  def generate_next_url
    if eds_session.has_key? :query_string
      url = HTMLEntities.new.decode eds_session[:query_string]

      #blacklight expects the search term to be in the parameter 'q'.
      #q is moved back to 'query-1' in 'generate_api_query'
      #should probably pull from Info method to determine replacement strings
      #i could turn the query into a Hash, but available functions to do so delete duplicated params (Addressable)
      url.gsub!("query-1=AND,TI:", "q=")
      url.gsub!("query-1=AND,AU:", "q=")
      url.gsub!("query-1=AND,SU:", "q=")
      url.gsub!("query-1=AND,", "q=")

      #Rails framework doesn't allow repeated params.  turning these into arrays fixes it.
      url.gsub!("facetfilter=", "facetfilter[]=")
      url.gsub!("limiter=", "limiter[]=")

      #i should probably pull this from the query, not the URL
      if (params[:search_field]).present?
        url << "&search_field=" << params[:search_field].to_s
      end
      return url
    else
      return ''
    end
  end

  # Returns URL with appened eds_action
  def eds_action_url eds_action
    search_action_url + '?' + generate_next_url + '&eds_action=' + eds_action
  end

  #for the search form at the top of results
  #retains some of current search's fields (limiters)
  #discards pagenumber, facets and filters, actions, etc.
  def show_hidden_field_tags
    hidden_fields = "";
    params.except(:search_field, :fromDetail, :facetfilter, :pagenumber, :q, :dbid, :an, :fulltext_type) do |key, value|
      if key == :eds_action
        if value =~ /addlimiter/ or value =~ /removelimiter/ or value =~ /setsort/ or value =~ /SetResultsPerPage/
          hidden_fields << '<input type="hidden" name="' << key.to_s << '" value="' << value.to_s << '" />'
        end
      elsif value.kind_of?(Array)
        value.each do |v|
          hidden_fields << '<input type="hidden" name="' << key.to_s << '[]" value="' << v.to_s << '" />'
        end
      else
        hidden_fields << '<input type="hidden" name="' << key.to_s << '" value="' << value.to_s << '" />'
      end
    end
    hidden_fields.html_safe
  end

  #############
  # Facets / Limiters sidebar
  #############

  def show_limiter_checkbox limiter, count
    applied_limiter = @results.fetch('SearchRequestGet', {}).fetch('SearchCriteriaWithActions', {}).
        fetch('LimitersWithAction', []).find { |applied_limiter|
      applied_limiter["Id"] == limiter["Id"]
    }
    limiter_checked = applied_limiter.present?
    limiter_action = limiter_checked ? applied_limiter["RemoveAction"].to_s : limiter["AddAction"].to_s.gsub('value', 'y')
    check_box_tag("limiters", limiter_action, limiter_checked, :id => ("limiter-" + count.to_s), :style => "margin-top:-5px;")
  end

  def show_date_link prior
    current_year = Time.new.year
    url = eds_action_url "addlimiter(DT1:#{(current_year - prior).to_s}-01/#{current_year.to_s}-12)"
    link_to "Last #{prior} Years", url
  end

  #############
  # Sort / Display / Record Count
  #############

  # pull sort options from INFO method
  def show_sort_options
    sortDropdown = ""
    eds_info.fetch('AvailableSearchCriteria', {}).fetch('AvailableSorts', []).each do |sort_option|
      sortDropdown << "<li><a href='#{eds_action_url sort_option["AddAction"].to_s}'>#{sort_option["Label"].to_s}</a></li>"
    end
    sortDropdown.html_safe
  end

  # shows currently selected view
  def show_view_option
    uri = Addressable::URI.parse(request.fullpath.split("?")[0] + "?" + generate_next_url)
    newUri = uri.query_values
    if newUri['view'].present?
      view_option = newUri['view'].to_s
    else
      view_option = "detailed"
    end
    return view_option
  end

  # shows currently selected sort
  def show_current_sort
    current_sort = params[:eds_action].present? ? params[:eds_action].gsub("setsort(", "").gsub(")", "") : nil
    current_sort = params[:sort].present? ? params[:sort] : nil if current_sort.nil?

    sort_option = eds_info.fetch('AvailableSearchCriteria', {}).fetch('AvailableSorts', []).find { |sort_option|
      sort_option['Id'].to_s == current_sort
    }
    sort = sort_option.present? ? sort_option['Label'] : 'Relevance'
    "Sort by #{sort}"
  end


  #############
  # Facet / Limiter Constraints Box
  #############

  # used when determining if the "constraints" partial should display
  def query_has_facetfilters?(localized_params = params)
    (generate_next_url.scan("facetfilter[]=").length > 0) or (generate_next_url.scan("limiter[]=").length > 0)
  end

  # should probably return a hash and let the view handle the HTML
  def show_applied_facets
    applied_facets = '';
    @results.fetch('SearchRequestGet', {}).fetch('SearchCriteriaWithActions', {}).
        fetch('FacetFiltersWithAction', []).each do |applied_facet|
      applied_facet['FacetValuesWithAction'].each do |facet_value|
        options = {
            class: "filter-#{facet_value['FacetValue']['Id'].to_s.gsub('EDS', '').gsub(' ', '').titleize}",
            remove_action: facet_value['RemoveAction'].to_s,
            filter_name: facet_value['FacetValue']['Id'].to_s.gsub("EDS", "").titleize,
            filter_value: facet_value['FacetValue']['Value'].to_s.titleize
        }
        applied_facets << render('constraints_element', options: options)
      end
    end
    applied_facets.html_safe
  end

  # should return hash and let the view handle the HTML
  def show_applied_limiters
    appliedlimiters = '';
    @results.fetch('SearchRequestGet', {}).fetch('SearchCriteriaWithActions', {}).
        fetch('LimitersWithAction', []).each do |applied_limiter|
      limiter = eds_info.fetch('AvailableSearchCriteria', {}).fetch('AvailableLimiters', []).find { |limiter|
        limiter["Id"] == applied_limiter["Id"]
      }
      limiter_label = limiter.present? ? limiter["Label"] : 'No Label'
      options = {
          class: "filter-#{applied_limiter["Id"]}",
          remove_action: applied_limiter["RemoveAction"]
      }

      if applied_limiter["Id"] == "DT1"
        applied_limiter["LimiterValuesWithAction"].each do |limiter_values|
          options[:filter_name] = limiter_label.to_s.titleize
          options[:filter_value] = limiter_values["Value"].gsub("-01/", " to ").gsub("-12", "")
          appliedlimiters << render('constraints_element', options: options)
        end
      else
        options.delete :filter_name
        options[:filter_value] = limiter_label.to_s.titleize
        appliedlimiters << render('constraints_element', options: options)
      end
    end
    appliedlimiters.html_safe
  end


  ###########
  # Pagination
  ###########

  #display how many results are being shown
  def show_results_per_page
    if params[:eds_action].present?
      if params[:eds_action].to_s.scan(/SetResultsPerPage/).length > 0
        rpp = params[:eds_action].to_s.gsub("SetResultsPerPage(", "").gsub(")", "").to_i
        return rpp
      end
    end
    if params[:resultsperpage].present?
      return params[:resultsperpage].to_i
    end
    return 20
  end

  #calculates total number of pages in results set
  def show_total_pages
    pages = show_total_hits / show_results_per_page
    return pages + 1
  end

  #get current page, which serves as a base for most pagination functions
  def show_current_page
    if params[:eds_action].present?
      if params[:eds_action].scan(/GoToPage/).length > 0
        pagenum = params[:eds_action].to_s
        newpagenum = pagenum.gsub("GoToPage(", "")
        newpagenum = newpagenum.gsub(")", "")
        return newpagenum.to_i
      elsif params[:eds_action].scan(/SetResultsPerPage/).length > 0
        if params[:pagenumber].present?
          return params[:pagenumber].to_i
        else
          return 1
        end
      else
        return 1
      end
    end
    if params[:pagenumber].present?
      return params[:pagenumber].to_i
    end
    return 1
  end

  #display pagination at the top of the results list
  def show_compact_pagination
    previous_link = ''
    next_link = ''
    first_result_on_page_num = ((show_current_page - 1) * show_results_per_page) + 1
    last_result_on_page_num = first_result_on_page_num + show_results_per_page - 1
    if last_result_on_page_num > show_total_hits
      last_result_on_page_num = show_total_hits
    end
    page_info = "<strong>" + first_result_on_page_num.to_s + "</strong> - <strong>" + last_result_on_page_num.to_s + "</strong> of <strong>" + show_total_hits.to_s + "</strong>"
    if show_current_page > 1
      previous_page = show_current_page - 1
      previous_link = '<a href="' + eds_action_url("GoToPage(#{previous_page.to_s})") + '">&laquo; Previous</a> | '
    end
    if (show_current_page * show_results_per_page) < show_total_hits
      next_page = show_current_page + 1
      next_link = ' | <a href="' + eds_action_url("GoToPage(#{next_page.to_s})") + '">Next &raquo;</a>'
    end
    compact_pagination = previous_link + page_info + next_link
    return compact_pagination.html_safe
  end

  def eds_page_entries_info
    first_result_on_page_num = ((show_current_page - 1) * show_results_per_page) + 1
    last_result_on_page_num = first_result_on_page_num + show_results_per_page - 1
    if last_result_on_page_num > show_total_hits
      last_result_on_page_num = show_total_hits
    end
    "<strong>" + first_result_on_page_num.to_s + "</strong> - <strong>" + last_result_on_page_num.to_s + "</strong> of <strong>" + show_total_hits.to_s + "</strong>"

  end

  #bottom pagination.  commented out lines remove 'last page' link, as this is not currently supported by the API
  def show_pagination
    previous_link = ''
    next_link = ''
    page_num_links = ''

    if show_current_page > 1
      previous_page = show_current_page - 1
      previous_link = '<li class=""><a href="' + eds_action_url("GoToPage(#{previous_page.to_s})") + '">&laquo; Previous</a></li>'
    else
      previous_link = '<li class="disabled"><a href="">&laquo; Previous</a></li>'
    end

    if (show_current_page * show_results_per_page) < show_total_hits
      next_page = show_current_page + 1
      next_link = '<li class=""><a href="' + eds_action_url("GoToPage(#{next_page.to_s})") +'">Next &raquo;</a></li>'
    else
      next_link = '<li class="disabled"><a href="">Next &raquo;</a></li>'
    end

    if show_current_page >= 4
      page_num_links << '<li class=""><a href="' + eds_action_url("GoToPage(1)") + '">1</a></li>'
    end
    if show_current_page >= 5
      page_num_links << '<li class="disabled"><a href="">...</a></li>'
    end

    # show links to the two pages the the left and right (where applicable)
    bottom_page = show_current_page - 2
    if bottom_page <= 0
      bottom_page = 1
    end
    top_page = show_current_page + 2
    if top_page >= show_total_pages
      top_page = show_total_pages
    end
    (bottom_page..top_page).each do |i|
      unless i == show_current_page
        page_num_links << '<li class=""><a href="' + eds_action_url("GoToPage(#{i.to_s})") + '">' + i.to_s + '</a></li>'
      else
        page_num_links << '<li class="disabled"><a href="">' + i.to_s + '</a></li>'
      end
    end

    if show_total_pages >= (show_current_page + 3)
      page_num_links << '<li class="disabled"><a href="">...</a></li>'
    end

    pagination_links = previous_link + next_link + page_num_links
    return pagination_links.html_safe
  end

  ###############
  # Results List
  ###############

  def has_restricted_access?(result)
    result.fetch('Header', {}).fetch('AccessLevel', '') == '1'
  end

  def show_total_hits
    eds_session[:total_hits] ||= @results.present? ? @results['SearchResult']['Statistics']['TotalHits'].to_i : 0
  end

  # see if title is available given a single result
  def has_titlesource?(result)
    result.fetch('Items', []).find { |item|
      item['Group'].downcase == "src"
    }.present?
  end

  # display title given a single result
  def show_titlesource(result)
    item = result.fetch('Items', []).find { |item|
      item['Group'].downcase == "src"
    }
    item.present? ? processAPItags(item['Data'].to_s).html_safe : ''
  end

  def has_subjects?(result)
    subject = result.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('Subjects', nil)
    subject.present? and subject.count > 0
  end

  def show_subjects(result)
    # need to update this to look in granular data fields

    subject_array = result.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('Subjects', []).reject { |subject|
      not subject.has_key? 'SubjectFull'
    }.map { |subject|
      url_vars = {"q" => '"' + subject['SubjectFull'].to_s + '"', "search_field" => "subject"}
      link2 = generate_next_url_newvar_from_hash(url_vars) << "&eds_action=GoToPage(1)"
      if params[:dbid].present?
        '<a href="' + request.fullpath.split("/" + params[:dbid])[0] + "?" + link2 + '">' + subject['SubjectFull'].to_s + '</a>'
      else
        '<a href="' + request.fullpath.split("?")[0] + "?" + link2 + '">' + subject['SubjectFull'].to_s + '</a>'
      end
    }

    subject_array.join(", ").html_safe
  end

  def has_pubdate?(result)
    result.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).
        fetch('IsPartOfRelationships', []).each do |isPartOfRelationship|
      isPartOfRelationship.fetch('BibEntity', {}).fetch('Dates', []).each do |date|
        return true if date['Type'] == 'published'
      end
    end
    return false
  end

  def show_pubdate(result)
    # check to see if there is a PubDate ITEM
    # Wiki Page on ITEM GROUPS
    flag = 0
    pubdate = ''
    result.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).
        fetch('IsPartOfRelationships', []).each do |isPartOfRelationship|
      isPartOfRelationship.fetch('BibEntity', {}).fetch('Dates', []).each do |date|
        if date['Type'] == "published" and flag == 0
          flag = 1
          if date['M'].present? and date['D'].present? and date['Y'].present?
            pubdate << date['M'] << "/" << date['D'] << "/" << date['Y']
          elsif date['M'].present? and date['Y'].present?
            pubdate << date['M'] << "/" << date['Y']
          elsif date['Y'].present?
            pubdate << date['Y']
          else
            pubdate << "Not available."
          end
        end
      end
    end
    return pubdate
  end

  def has_pubtype?(result)
    result.fetch('Header', {}).fetch('PubType', nil).present?
  end

  def show_pubtype(result)
    result.fetch('Header', {}).fetch('PubType', '')
  end

  def has_pubtypeid?(result)
    result.fetch('Header', {}).fetch('PubTypeId', nil).present?
  end

  def show_pubtypeid(result)
    result.fetch('Header', {}).fetch('PubTypeId', '')
  end

  def has_coverimage?(result)
    result.fetch('ImageInfo', []).find { |cover_art|
      cover_art['Size'] == 'thumb'
    }.present?
  end

  def show_coverimage_link(result)
    cover_art = result.fetch('ImageInfo', []).find { |cover_art|
      cover_art['Size'] == 'thumb'
    }
    cover_art.present? ? cover_art['Target'] : ''
  end

  def has_abstract?(result)
    result.fetch('Items', []).find { |item|
      item.fetch('Group', '') == 'Ab'
    }.present?
  end

  def show_abstract(result)
    abstractString = ''
    result.fetch('Items', []).each do |item|
      abstractString << item['Data'] if item.fetch('Group', '') == 'Ab'
    end
    HTMLEntities.new.decode(abstractString).html_safe
  end

  def has_authors?(result)
    return true if result.fetch('Items', []).find { |item|
      item.fetch('Group', '') == 'Au'
    }.present?

    result.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).
        fetch('HasContributorRelationships', []).find { |contributor|
      contributor.has_key? 'PersonEntity'
    }.present?
  end

  # this should make use of AddQuery / RemoveQuery - but there might be a conflict with the "q" variable
  def show_authors(result)
    author_array = []
    if result['Items'].present?
      flag = 0
      authorString = []
      result['Items'].each do |item|
        if item['Group'].present?
          if item['Group'] == "Au"
            # let Don and Michelle know what this cleaner function does
            newAuthor = processAPItags(item['Data'].to_s)
            # i'm duplicating the semicolor - fix
            newAuthor.gsub!("<br />", "; ")
            authorString.push(newAuthor)
            flag = 1
          end
        end
      end
      if flag == 1
        return truncate_article authorString.join("; ").html_safe
      end
    end
    contributors = result.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('HasContributorRelationships', [])
    if not contributors.empty?
      contributors.each do |contributor|
        namefull = contributor.fetch('PersonEntity', {}).fetch('Name', {}).fetch('NameFull', nil)
        if namefull
          url_vars = {"q" => '"' + namefull.gsub(",", "").gsub("%2C", "").to_s + '"', "search_field" => "author"}
          link2 = generate_next_url_newvar_from_hash(url_vars)
          author_link = '<a href="' + request.fullpath.split("?")[0] + "?" + link2 + '">' + namefull.to_s + '</a>'
          author_array.push(author_link)
        end

      end
      return author_array.join("; ").html_safe
    end
    return ''
  end

  def show_resultid(result)
    return result['ResultId'].to_s
  end

  def show_title(result)
    result.fetch('Items',[]).each do |item|
      if item['Group'] == 'Ti'
        return truncate_article HTMLEntities.new.decode(item['Data']).html_safe
      end
    end
    titles = result.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('Titles', []).map { |title|
      title['TitleFull'].to_s
    }
    titles.empty? ? 'Title not available.' : titles.join('/').html_safe
  end

  def show_results_array
    @results.inspect
  end

  def has_full_text_on_screen?(result)
    result.fetch('FullText', {}).fetch('Text', {}).fetch('Availability', '0') == '1'
  end

  def show_full_text_on_screen(result)
    HTMLEntities.new.decode(result['FullText']['Text']['Value']) if has_full_text_on_screen? result
  end

  ################
  # Full Text Links
  ################

  def has_any_fulltext?(result)
    has_pdf? result or has_html? result or has_smartlink? result or has_fulltext? result or has_epub? result or has_other_custom_links? result
  end

  def show_an(result)
    an = result.fetch('Header', {}).fetch('An', nil)
    an.present? ? an.to_s : nil
  end

  def show_dbid(result)
    dbid = result.fetch('Header', {}).fetch('DbId', nil)
    dbid.present? ? dbid.to_s : nil
  end

  def show_detail_link(result, resultId = "0", highlight = "")
    link = ''
    highlight.gsub! '&quot;', '%22'

    an = show_an result
    dbid = show_dbid result
    if an and dbid
      link = "articles/#{dbid}/#{url_encode(an)}/"
      params = {}
      params['resultId'] = resultId.to_s if resultId.to_i > 0
      params['highlight'] = highlight.to_s unless highlight.empty?
      link << '?' << params.map { |k, v| "#{k}=#{v}" }.join('&') unless params.empty?
    end
    link
  end

  def show_best_fulltext_link(result)
    if has_pdf?(result)
      return show_pdf_title_link(result)
    elsif has_html?(result)
      return path_for_eds_article dbid: show_dbid(result), an: show_an(result), resultId: show_resultid(result), highlight: params[:q]
    elsif has_smartlink?(result)
      return show_smartlink_title_link(result)
    elsif has_fulltext?(result)
      return best_customlink(result)
    end
    return ''
  end

  # generate full text link for the detailed record area (not the title link)
  def show_best_fulltext_link_detail(result)
    if has_pdf?(result)
      link = '<a href="' + show_pdf_title_link(result) + '">PDF Full Text</a>'
    elsif has_html?(result)
      link = '<a href="' + show_best_fulltext_link(result) + '" target="_blank">HTML Full Text</a>'
    elsif has_smartlink?(result)
      link = '<a href="' + show_smartlink_title_link(result) + '">Linked Full Text</a>'
    elsif has_fulltext_customlink?(result)
      link = best_customlink_detail(result)
    else
      link = ''
    end
    return link.html_safe
  end

  def has_pdf?(result)
    result.fetch('FullText', {}).fetch('Links', []).find { |link|
      link['Type'] == 'pdflink' or link['Type'] == 'ebook-pdf'
    }.present?
  end

  def has_html?(result)
    result.fetch('FullText', {}).fetch('Text', {}).fetch('Availability', 0).to_s == '1'
  end

  def has_fulltext_customlink?(result)
    result.fetch('FullText', {}).fetch('CustomLinks', []).find { |link|
      link['Category'] == 'fullText'
    }.present?
  end

  def has_smartlink?(result)
    result.fetch('FullText', {}).fetch('Links', []).find { |link|
      link['Type'] == 'other'
    }.present?
  end

  def has_fulltext?(result)
    has_pdf?(result) or has_html?(result) or has_epub?(result) or has_smartlink?(result) or has_fulltext_customlink?(result)
  end

  def has_epub?(result)
    result.fetch('FullText', {}).fetch('Links', []).find { |link|
      link['Type'] == 'ebook-epub'
    }.present?
  end

  def show_plink(result)
    result.fetch('PLink', '')
  end

  def show_pdf_title_link(result)
    title_pdf_link = ''
    if result['Header']['DbId'].present? and result['Header']['An'].present?
      title_pdf_link << request.fullpath.split("?")[0] << "/" << result['Header']['DbId'].to_s << "/" << result['Header']['An'].to_s << "/fulltext"
    end
    new_link = Addressable::URI.unencode(title_pdf_link.to_s)
    return new_link
  end

  def show_smartlink_title_link(result)
    title_pdf_link = ''
    if result['Header']['DbId'].present? and result['Header']['An'].present?
      title_pdf_link << request.fullpath.split("?")[0] << "/" << result['Header']['DbId'].to_s << "/" << result['Header']['An'].to_s << "/fulltext"
    end
    new_link = Addressable::URI.unencode(title_pdf_link.to_s)
    return new_link
  end

  def show_ebook_title_link(result)
    title_pdf_link = ''
    if result['Header']['DbId'].present? and result['Header']['An'].present?
      title_pdf_link << request.fullpath.split("?")[0] << "/" << result['Header']['DbId'].to_s << "/" << result['Header']['An'].to_s << "/fulltext"
    end
    new_link = Addressable::URI.unencode(title_pdf_link.to_s)
    return new_link
  end

  def show_pdf_link(result)
    result.fetch('FullText', {}).fetch('Links', []).select { |link|
      link['Type'] == 'pdflink'
    }.fetch('Url', '')
  end

  def show_smartlink(result)
    result.fetch('FullText', {}).fetch('Links', []).select { |link|
      link['Type'] == 'other'
    }.map { |link| link['Url'] }.join
  end

  def show_ebook_link(result)
    result.fetch('FullText', {}).fetch('Links', []).select { |link|
      link['Type'] == 'ebook-pdf' or link['Type'] == 'ebook-epub'
    }.map { |link| link['Url'] }.join
  end

  def show_fulltext_customlink(result)
    result.fetch('FullText', {}).fetch('CustomLinks', []).select { |customLink|
      customLink['Category'] == 'fullText'
    }.map { |custom_link|
      open_tag = "<img src=\"".html_safe
      close_tag = "\" border=\"0\" alt=\" \"  />".html_safe
      img_tag = custom_link['Icon'].present? ?   open_tag   + custom_link['Icon'] + close_tag   : ''
      text = custom_link.fetch('Text', 'Full Text via Custom Link')
      link_to img_tag + text, custom_link['Url'], target: '_blank'
    }
  end

  # show prioritized custom links
  def best_customlink(result)
    fulltext_link = result.fetch('FullText', {}).fetch('CustomLinks', []).find { |custom_link|
      custom_link['Category'] == 'fullText'
    }
    fulltext_link.present? ? fulltext_link['Url'] : ''
  end

  def best_customlink_detail(result)
    custom_link = result.fetch('FullText', {}).fetch('CustomLinks', []).find { |custom_link|
      custom_link['Category'] == 'fullText'
    }
    open_tag = "<img src=\"".html_safe
    close_tag = "\" border=\"0\" alt=\" \"  />".html_safe
    img_tag = custom_link['Icon'].present? ?   open_tag   + custom_link['Icon'] + close_tag   : ''
    text = custom_link.fetch('Text', 'Full Text via Custom Link')
    link_to img_tag + text, custom_link['Url'], target: '_blank'
    
  end

  def has_ill?(result)
    result.fetch('CustomLinks', []).find { |link|
      link['Category'] == 'ill'
    }.present?
  end

  def show_ill(result)
    result.fetch('CustomLinks', []).select { |link|
      link['Category'] == 'ill'
    }.map { |link|
      link_to 'Request via Interlibrary Loan', link['Url'], target: '_blank'
    }.join(' ').html_safe
  end

  def has_other_custom_links?(result)
    result.fetch('CustomLinks', []).find { |link|
      link['Category'] == 'other' and not link['Text'].blank?
    }.present?
  end

  def show_other_custom_links(result)
    result.fetch('CustomLinks', []).select { |link|
      link['Category'] == 'other' and not link['Text'].blank?
    }.map { |link|
      if link.fetch('Icon', nil).present?
        label = image_tag(link['Icon']) + ' ' + link['Text']
      else
        label = link['Text']
      end
      link_to label, link['Url'], target: '_blank'
    }
  end


  def has_eds_pointer?
    !params[:eds].blank? or !params[:eds_q].blank?
  end

  def show_sort_and_per_page? response = nil
    response ||= @response
    response.response['numFound'] > 1
  end

  # cleans response from EBSCO API
  def processAPItags(apiString)
    processed = HTMLEntities.new.decode apiString
    return processed.html_safe
  end

  # should replace this functionality with AddQuery/RemoveQuery actions
  def generate_next_url_newvar_from_hash(variablehash)
    uri = Addressable::URI.parse(request.fullpath.split("?")[0] + "?" + generate_next_url)
    newUri = uri.query_values.merge variablehash
    uri.query_values = newUri
    return uri.query.to_s
  end

  # whether the results list have records
  def has_records? results
    not results.nil? and results.fetch('SearchResult', {}).fetch('Data', {}).fetch('Records', []).count > 0
  end

  def truncate_article(s, length = 250, ellipsis = '...')
    s = strip_tags s
    if s.length > length
      s.to_s[0..length].gsub(/[^\w]\w+\s*$/, ellipsis).sub(/(,|;)(\...)/, ellipsis)
    else
      s
    end
  end

end
