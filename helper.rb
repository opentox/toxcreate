helpers do

  def login(username, password)
    logout
    session[:subjectid] = OpenTox::Authorization.authenticate(username, password)
    LOGGER.debug "ToxCreate login user #{username} with subjectid: " + session[:subjectid].to_s
    if session[:subjectid] != nil
      session[:username] = username
      return true
    else
      session[:username] = ""
      return false
    end
  end

  def logout
    if session[:subjectid] != nil
      session[:subjectid] = nil
      session[:username] = ""
      return true
    end
    return false
  end

  def logged_in()
    return true if !AA_SERVER
    if session[:subjectid] != nil
      return OpenTox::Authorization.is_token_valid(session[:subjectid])
    end
    return false
  end

  def is_authorized(uri, action)
    if OpenTox::Authorization.server && session[:subjectid] != nil
      return OpenTox::Authorization.authorize(uri, action, session[:subjectid])
    else
      return true
    end
    return false
  end

  def hide_link(destination)
    @link_id = 0 unless @link_id
    @link_id += 1
    haml :js_link, :locals => {:name => "hide", :destination => destination, :method => "hide"}, :layout => false
  end

  def toggle_link(destination,name)
    @link_id = 0 unless @link_id
    @link_id += 1
    haml :js_link, :locals => {:name => name, :destination => destination, :method => "toggle"}, :layout => false
  end

  def sort(descriptors)
    features = {:activating => [], :deactivating => []}

    descriptors.each { |d| LOGGER.debug d.inspect; features[d[OT.effect].to_sym] << {:smarts => d[OT.smarts],:p_value => d[OT.pValue]} }
    features
  end

  def compound_image(compound,descriptors)
    haml :compound_image, :locals => {:compound => compound, :features => sort(descriptors)}, :layout => false
  end
  
  def activity_markup(activity)
    case activity.class.to_s
    when /Float/
      haml ".other #{sprintf('%.03g', activity)}", :layout => false
    when /String/
      haml ".other #{activity.to_s}", :layout => false
    else
      if activity #true
        haml ".active active", :layout => false
      elsif !activity # false
        haml ".inactive inactive", :layout => false
      else
        haml ".other #{activity.to_s}", :layout => false
      end
    end
  end

  def neighbors_navigation
    @page = 0 unless @page
    haml :neighbors_navigation, :layout => false
  end

end

