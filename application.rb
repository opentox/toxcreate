['rubygems', "haml", "sass", "rack-flash"].each do |lib|
  require lib
end
gem "opentox-ruby", "~> 1"
require 'opentox-ruby'
gem 'sinatra-static-assets'
require 'sinatra/static_assets'
require 'ftools'
require File.join(File.dirname(__FILE__),'model.rb')
require File.join(File.dirname(__FILE__),'helper.rb')

use Rack::Session::Cookie, :expire_after => 28800, 
                           :secret => "ui6vaiNi-change_me"
use Rack::Flash

set :lock, true

helpers do 

  def error(message)
    LOGGER.error message
    @model.update :status => "Error", :error_messages => message
    flash[:notice] = message
    redirect url_for('/create')
  end

  private 
  def delete_model(model, subjectid=nil)
    task = OpenTox::Task.create("Deleting model: #{model.uri}",url_for("/delete",:full)) do |task|
      begin RestClient.put(File.join(model.task_uri, 'Cancelled'),subjectid) if model.task_uri rescue LOGGER.warn "Cannot cancel task #{model.task_uri}" end
      task.progress(15)
      delete_dependent(model.uri, subjectid) if model.uri
      task.progress(30)
      delete_dependent(model.validation_uri, subjectid) if model.validation_uri
      task.progress(45)
      delete_dependent(model.validation_report_uri, subjectid) if model.validation_report_uri
      task.progress(60)
      delete_dependent(model.validation_qmrf_uri, subjectid) if model.validation_qmrf_uri
      task.progress(75)
      delete_dependent(model.training_dataset, subjectid) if model.training_dataset
      task.progress(90)
      delete_dependent(model.feature_dataset, subjectid) if model.feature_dataset
      task.progress(100)
      ""
    end
  end

  def delete_dependent(uri, subjectid=nil)
    begin
      RestClient.delete(uri, :subjectid => subjectid) if subjectid
      RestClient.delete(uri) if !subjectid
    rescue
      LOGGER.warn "Can not delete uri: #{uri}"
    end
  end
end

before do
    if !logged_in and !( env['REQUEST_URI'] =~ /\/login$/ and env['REQUEST_METHOD'] == "POST" ) #or !AA_SERVER
      login("guest","guest")
    end
end

get '/?' do
  redirect url_for('/create')
end

get '/login' do
  haml :login
end

get '/models/?' do
  @models = ToxCreateModel.all.sort(:order => "DESC")
  subjectstring = session[:subjectid] ? "?subjectid=#{CGI.escape(session[:subjectid])}" : ""
  haml :models, :locals=>{:models=>@models, :subjectstring => subjectstring}
end

get '/model/:id/status/?' do
  response['Content-Type'] = 'text/plain'
  model = ToxCreateModel.get(params[:id])
  begin
    haml :model_status, :locals=>{:model=>model}, :layout => false
  rescue
    return "Model #{params[:id]} not available"
  end
end

get '/model/:id/progress/?' do
  response['Content-Type'] = 'text/plain'
  model = ToxCreateModel.get(params[:id])
  if model.task_uri 
    if (OpenTox::Task.exist?(model.task_uri))
      task = OpenTox::Task.exist?(model.task_uri) 
      percentage_completed = task.percentageCompleted
    end 
    begin
      haml :model_progress, :locals=>{:percentage_completed=>percentage_completed}, :layout => false
    rescue
      return "unavailable"
    end
  else
    return ""
  end
end

get '/model/:id/name/?' do
  response['Content-Type'] = 'text/plain'
  model = ToxCreateModel.get(params[:id])
  begin
    case params[:mode]
      when 'edit'
        haml :model_name_edit, :locals=>{:model=>model}, :layout => false
      when 'show'
        haml :model_name, :locals=>{:model=>model}, :layout => false
      else
        params.inspect
      end
  rescue
    return "unavailable"
  end
end

put '/model/:id/?' do
  response['Content-Type'] = 'text/plain'
  model = ToxCreateModel.get(params[:id])
  begin
    model.update :name => params[:name] if params[:name] && model.name != params[:name]
    redirect url_for("/model/#{model.id}/name?mode=show")
  rescue
    return "unavailable"
  end
end


get '/model/:id/:view/?' do
  response['Content-Type'] = 'text/plain'
  model = ToxCreateModel.get(params[:id])
  subjectstring = session[:subjectid] ? "?subjectid=#{CGI.escape(session[:subjectid])}" : ""
  begin
    case params[:view]
      when "model"
        haml :model, :locals=>{:model=>model,:subjectstring => subjectstring}, :layout => false
      when /validation/
        haml :validation, :locals=>{:model=>model,:subjectstring => subjectstring}, :layout => false
      else
        return "unable to render model: id #{params[:id]}, view #{params[:view]}"
    end
  rescue
    return "unable to render model: id #{params[:id]}, view #{params[:view]}"
  end
end

get '/predict/?' do 
  @models = ToxCreateModel.all.sort(:order => "DESC")
  @models = @models.collect{|m| m if m.status == 'Completed'}.compact
  haml :predict
end

get '/create' do
  haml :create
end

get '/help' do
  haml :help
end

get "/confidence" do
  haml :confidence
end

# proxy to get data from compound service
# (jQuery load does not work with external URIs)
get %r{/compound/(.*)} do |inchi|
  inchi = URI.unescape request.env['REQUEST_URI'].sub(/^\//,'').sub(/.*compound\//,'')
  OpenTox::Compound.from_inchi(inchi).to_names.join(', ')
end

post '/models' do # create a new model
  unless params[:file] and params[:file][:tempfile] #params[:endpoint] and 
    flash[:notice] = "Please upload a Excel or CSV file."
    redirect url_for('/create')
  end

  unless logged_in()
    logout
    flash[:notice] = "Please login to create a new model."
    redirect url_for('/create')
  end
  subjectid = session[:subjectid] ? session[:subjectid] : nil
  @model = ToxCreateModel.create(:name => params[:file][:filename].sub(/\..*$/,""), :subjectid => subjectid)
  @model.update :web_uri => url_for("/model/#{@model.id}", :full), :warnings => ""
  task = OpenTox::Task.create("Uploading dataset and creating lazar model",url_for("/models",:full)) do |task|

    task.progress(5)
    @model.update :status => "Uploading and saving dataset", :task_uri => task.uri
    begin
      @dataset = OpenTox::Dataset.create(nil, subjectid)
      # check format by extension - not all browsers provide correct content-type]) 
      case File.extname(params[:file][:filename])
      when ".csv"
        csv = params[:file][:tempfile].read
        @dataset.load_csv(csv, subjectid)
      when ".xls", ".xlsx"
        excel_file = params[:file][:tempfile].path + File.extname(params[:file][:filename])
        File.rename(params[:file][:tempfile].path, excel_file) # add extension, spreadsheet does not read files without extensions
        @dataset.load_spreadsheet(Excel.new excel_file, subjectid)
      else
        error "#{params[:file][:filename]} has a unsupported file type."
      end
    rescue => e
      error "Dataset creation failed with #{e.message}"
    end
    @dataset.save(subjectid)
    task.progress(10)
    if @dataset.compounds.size < 10
      error "Too few compounds to create a prediction model. Did you provide compounds in SMILES format and classification activities as described in the #{link_to "instructions", "/excel_format"}? As a rule of thumb you will need at least 100 training compounds for nongeneric datasets. A lower number could be sufficient for congeneric datasets."
    end
    if @dataset.features.keys.size != 1
      error "More than one feature in dataset #{params[:file][:filename]}. Please delete irrelvant columns and try again."
    end
    if @dataset.metadata[OT.Errors]
      error "Incorrect file format. Please follow the instructions for #{link_to "Excel", "/excel_format"} or #{link_to "CSV", "/csv_format"} formats."
    end
    @model.update :training_dataset => @dataset.uri, :nr_compounds => @dataset.compounds.size, :status => "Creating prediction model"
    @model.update :warnings => @dataset.metadata[OT.Warnings] unless @dataset.metadata[OT.Warnings].empty?
    task.progress(15)
    begin
      lazar = OpenTox::Model::Lazar.create({:dataset_uri => @dataset.uri, :subjectid => subjectid})
    rescue => e
      error "Model creation failed with '#{e.message}'. Please check if the input file is in a valid #{link_to "Excel", "/excel_format"} or #{link_to "CSV", "/csv_format"} format."
    end
    task.progress(25)
    type = "unknown"
    case lazar.metadata[OT.isA]
    when /Classification/
      type = "classification"
    when /Regression/
      type = "regression"
    end
    @model.update :type => type, :feature_dataset => lazar.metadata[OT.featureDataset], :uri => lazar.uri

    unless url_for("",:full).match(/localhost/)
      @model.update :status => "Validating model"
      begin
        validation = OpenTox::Crossvalidation.create(
          {:algorithm_uri => lazar.metadata[OT.algorithm],
          :dataset_uri => lazar.parameter("dataset_uri"),
          :subjectid => subjectid,
          :prediction_feature => lazar.parameter("prediction_feature"),
          :algorithm_params => "feature_generation_uri=#{lazar.parameter("feature_generation_uri")}"},
         nil, OpenTox::SubTask.new(task,25,80))
        @model.update(:validation_uri => validation.uri)
        LOGGER.debug "Validation URI: #{@model.validation_uri}"

        # create summary
        validation.summary(subjectid).each do |k,v|
          begin
            eval "@model.update :#{k.to_s} => v" if v
          rescue
            eval "@model.update :#{k.to_s} => 0"
          end
        end

        @model.update :status => "Creating validation report"
        validation_report_uri = validation.find_or_create_report(subjectid, OpenTox::SubTask.new(task,80,90)) #unless @model.dirty?
        @model.update :validation_report_uri => validation_report_uri, :status => "Creating QMRF report"
        qmrf_report = OpenTox::Crossvalidation::QMRFReport.create(@model.uri, subjectid, OpenTox::SubTask.new(task,90,99))
        @model.update(:validation_qmrf_uri => qmrf_report.uri, :status => "Completed")

      rescue => e
        LOGGER.debug "Model validation failed with #{e.message}."
        @model.save # to avoid dirty models
        @model.update :warnings => @model.warnings + "\nModel validation failed with #{e.message}.", :status => "Error", :error_messages => e.message
      end
      
    end


    #@model.warnings += "<p>Incorrect Smiles structures (ignored):</p>" + parser.smiles_errors.join("<br/>") unless parser.smiles_errors.empty?
    #@model.warnings += "<p>Irregular activities (ignored):</p>" + parser.activity_errors.join("<br/>") unless parser.activity_errors.empty?
    #duplicate_warnings = ''
    #parser.duplicates.each {|inchi,lines| duplicate_warnings += "<p>#{lines.join('<br/>')}</p>" if lines.size > 1 }
    #@model.warnings += "<p>Duplicated structures (all structures/activities used for model building, please  make sure, that the results were obtained from <em>independent</em> experiments):</p>" + duplicate_warnings unless duplicate_warnings.empty?
    lazar.uri
  end
  @model.update :task_uri => task.uri

  flash[:notice] = "Model creation and validation started - this may last up to several hours depending on the number and size of the training compounds."
  redirect url_for('/models')

end

post '/predict/?' do # post chemical name to model
  subjectid = session[:subjectid] ? session[:subjectid] : nil
  @identifier = params[:identifier]
  unless params[:selection] and params[:identifier] != ''
    flash[:notice] = "Please enter a compound identifier and select an endpoint from the list."
    redirect url_for('/predict')
  end
  begin
    @compound = OpenTox::Compound.from_name(params[:identifier])
  rescue
    flash[:notice] = "Could not find a structure for '#{@identifier}'. Please try again."
    redirect url_for('/predict')
  end
  @predictions = []
  params[:selection].keys.each do |id|
    model = ToxCreateModel.get(id.to_i)
    prediction = nil
    confidence = nil
    title = nil
    db_activities = []
    lazar = OpenTox::Model::Lazar.new model.uri
    prediction_dataset_uri = lazar.run({:compound_uri => @compound.uri, :subjectid => subjectid})
    prediction_dataset = OpenTox::LazarPrediction.find(prediction_dataset_uri, subjectid)
    if prediction_dataset.metadata[OT.hasSource].match(/dataset/)
      @predictions << {
        :title => model.name,
        :measured_activities => prediction_dataset.measured_activities(@compound)
      }
    else
      predicted_feature = prediction_dataset.metadata[OT.dependentVariables]
      prediction = OpenTox::Feature.find(predicted_feature)
      if prediction.metadata[OT.error]
        @predictions << {
          :title => model.name,
          :error => prediction.metadata[OT.error]
          }
      else
        @predictions << {
          :title => model.name,
          :model_uri => model.uri,
          :prediction => prediction.metadata[OT.prediction],
          :confidence => prediction.metadata[OT.confidence]
          }
      end
    end
    # TODO failed/unavailable predictions
  end

  haml :prediction
end

post "/lazar/?" do # get detailed prediction
  @page = 0
  @page = params[:page].to_i if params[:page]
  @model_uri = params[:model_uri]
  lazar = OpenTox::Model::Lazar.new @model_uri
  prediction_dataset_uri = lazar.run(:compound_uri => params[:compound_uri], :subjectid => params[:subjectid])
  @prediction = OpenTox::LazarPrediction.find(prediction_dataset_uri, session[:subjectid])
  @compound = OpenTox::Compound.new(params[:compound_uri])
  haml :lazar
end

post '/login' do
  if params[:username] == '' || params[:password] == ''
    flash[:notice] = "Please enter username and password."
    redirect url_for('/login')
  end
  if login(params[:username], params[:password])
    flash[:notice] = "Welcome #{session[:username]}!"
    redirect url_for('/create')
  else
    flash[:notice] = "Login failed. Please try again."
    haml :login
  end
end

post '/logout' do
  logout
  redirect url_for('/login')
end

delete '/model/:id/?' do
  model = ToxCreateModel.get(params[:id])
  raise OpenTox::NotFoundError.new("Model with id: #{params[:id]} not found!") unless model
  begin
    delete_model(model, @subjectid)   
    model.delete
    unless ToxCreateModel.get(params[:id])
      begin
        aa = OpenTox::Authorization.delete_policies_from_uri(model.web_uri, @subjectid)
        LOGGER.debug "Policy deleted for Dataset URI: #{uri} with result: #{aa}"
      rescue
        LOGGER.warn "Policy delete error for Dataset URI: #{uri}"
      end
    end
    flash[:notice] = "#{model.name} model deleted."
  rescue
    flash[:notice] = "#{model.name} model delete error."
  end
  redirect url_for('/models')
end

delete '/?' do
  ToxCreateModel.all.each do |model| 
    begin
      delete_model(model, @subjectid)   
      model.delete
      unless ToxCreateModel.get(params[:id])
        begin
          aa = OpenTox::Authorization.delete_policies_from_uri(model.web_uri, @subjectid)
          LOGGER.debug "Policy deleted for Dataset URI: #{uri} with result: #{aa}"
        rescue
          LOGGER.warn "Policy delete error for Dataset URI: #{uri}"
        end
      end
      LOGGER.debug "#{model.name} model deleted."
    rescue
      LOGGER.error "#{model.name} model delete error."
    end
  end
  response['Content-Type'] = 'text/plain'
  "All Models deleted."
end

# SASS stylesheet
get '/stylesheets/style.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :style
end
