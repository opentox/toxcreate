post '/policy/:policyname/?' do
  response['Content-Type'] = 'text/plain'
  model = ToxCreateModel.get(params[:id])
  begin
    redirect url_for("/model/#{model.id}/name?mode=update&policyname=#{params[:policyname]}&groupname=#{params[:groupname]}&select=#{params[:select]}")
  rescue
    return "unavailable"
  end
end

post '/policy/?' do
  response['Content-Type'] = 'text/plain'
  model = ToxCreateModel.get(params[:id])
  begin
    redirect url_for("/model/#{model.id}/name?mode=add&groupname=#{params[:groupname]}&selection=#{params[:selection]}")
  rescue
    return "unavailable"
  end
end
