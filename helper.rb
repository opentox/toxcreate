helpers do

  def is_authorized(uri, action)
    if OpenTox::Authorization.server && session[:subjectid] != nil
      return OpenTox::Authorization.authorized?(uri, action, session[:subjectid])
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

  def sort(descriptors,value_map)
    features = {:activating => [], :deactivating => []}
    descriptors.each do |d|
      if !value_map.empty?
        features[:activating] << {:smarts => d[OT.smarts],:p_value => d[OT.pValue]} if d[OT.effect] == 2
        features[:deactivating] << {:smarts => d[OT.smarts],:p_value => d[OT.pValue]} if d[OT.effect] == 1
      else
        if d[OT.effect] =~ TRUE_REGEXP 
          features[:activating] << {:smarts => d[OT.smarts],:p_value => d[OT.pValue]} 
        elsif d[OT.effect] =~ FALSE_REGEXP 
          features[:deactivating] << {:smarts => d[OT.smarts],:p_value => d[OT.pValue]} 
        end
      end
    end
    features
  end

  def compound_image(compound,descriptors,value_map)
    haml :compound_image, :locals => {:compound => compound, :features => sort(descriptors,value_map)}, :layout => false
  end
  
  def activity_markup(activity,value_map)
    if value_map and !value_map.empty?
      if value_map.size == 2
        activity = value_map.index(activity) if value_map.has_value? activity
        if activity.to_i == 2
          haml ".active #{value_map[activity]}", :layout => false
        elsif activity.to_i == 1
          haml ".inactive #{value_map[activity]}", :layout => false
        else
          haml ".other #{activity.to_s}", :layout => false
        end
      else
        haml ".other #{activity.to_s}", :layout => false
      end
    elsif OpenTox::Algorithm::numeric? activity
      haml ".other #{sprintf('%.03g', activity.to_f)}", :layout => false
    else
      haml ".other #{activity.to_s}", :layout => false
    end
=begin
    case activity.class.to_s
    when /Float/
      haml ".other #{sprintf('%.03g', activity)}", :layout => false
    when /String/
      case activity
      when "true"
        haml ".active active", :layout => false
      when "false"
        haml ".inactive inactive", :layout => false
      else
        haml ".other #{activity.to_s}", :layout => false
      end
    else 
      if activity #true
        haml ".active active", :layout => false
      elsif !activity # false
        haml ".inactive inactive", :layout => false
      else
        haml ".other #{activity.to_s}", :layout => false
      end
    end
=end
  end

  def neighbors_navigation
    @page = 0 unless @page
    haml :neighbors_navigation, :layout => false
  end

end

