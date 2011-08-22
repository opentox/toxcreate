['rubygems', "haml", "sass", "rack-flash"].each do |lib|
  require lib
end
gem "opentox-ruby", "~> 2"
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

  # message will be displayed to the user
  # error will be raised -> taks will be set to error -> error details available via task-uri
  def error(message, error=nil)
    LOGGER.error message
    @model.update :status => "Error", :error_messages => message
    if error
      raise error
    else
      raise message
    end
  end

  private 
  def delete_model(model, subjectid=nil)
    task = OpenTox::Task.create("Deleting model: #{model.uri}",url_for("/delete",:full)) do |task|
      begin OpenTox::RestClientWrapper.put(File.join(model.task_uri, "Cancelled"), "Cancelled",{:subjectid => subjectid}) if model.task_uri rescue LOGGER.warn "Cannot cancel task #{model.task_uri}" end
      task.progress(15)
      delete_dependent(model.uri, subjectid) if model.uri
      task.progress(30)
      delete_dependent(model.validation_uri, subjectid) if model.validation_uri
      task.progress(45)
      delete_dependent(model.validation_report_uri, subjectid) if model.validation_report_uri
      task.progress(60)
      delete_dependent(model.validation_qmrf_uri, subjectid) if model.validation_qmrf_uri
      task.progress(75)
      if model.training_dataset
        delete_dependent(model.training_dataset, subjectid) if model.training_dataset.match(CONFIG[:services]["opentox-dataset"])
      end 
      task.progress(90)
      if model.feature_dataset
        delete_dependent(model.feature_dataset, subjectid) if model.feature_dataset.match(CONFIG[:services]["opentox-dataset"])
      end
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
    if !logged_in and !( env['REQUEST_URI'] =~ /\/login$/ and env['REQUEST_METHOD'] == "POST" ) or !AA_SERVER
      login("guest","guest")
    end
end

get '/?' do
  redirect url_for('/predict')
end

get '/login' do
  haml :login
end

get '/models/?' do
  @models = ToxCreateModel.all.sort(:order => "DESC")
  @models.each{|m| raise "internal redis error: model is nil" unless m}
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
=begin
get '/create' do
  haml :create
end
=end
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

get '/echa' do
  @endpoints = OpenTox::Ontology::Echa.endpoints
  haml :echa
end

post '/ambit' do
  session[:echa] = params[:endpoint]
  @datasets  = OpenTox::Ontology::Echa.datasets(params[:endpoint])
  haml :ambit
end

post '/feature' do
  session[:dataset] = params[:dataset]
  @features = []
  OpenTox::Dataset.new(params[:dataset]).load_features.each do |uri,metadata|
    @features << OpenTox::Feature.find(uri, @subjectid) if metadata[OWL.sameAs].match(/#{session[:echa]}/)
  end
  haml :feature
end

post '/models' do # create a new model

  unless (params[:dataset] and params[:prediction_feature]) or (params[:file] and params[:file][:tempfile]) #params[:endpoint] and 
    flash[:notice] = "Please upload a Excel or CSV file or select an AMBIT dataset."
    redirect url_for('/create')
  end

  unless logged_in()
    logout
    flash[:notice] = "Please login to create a new model."
    redirect url_for('/create')
  end

  subjectid = session[:subjectid] ? session[:subjectid] : nil

  if params[:dataset] and params[:prediction_feature]
    @dataset = OpenTox::Dataset.new(params[:dataset],subjectid)
    name = @dataset.load_metadata[DC.title]
    @prediction_feature = OpenTox::Feature.find params[:prediction_feature], subjectid
    @dataset.load_compounds
  elsif params[:file][:filename]
    name = params[:file][:filename].sub(/\..*$/,"")
  end

  @model = ToxCreateModel.create(:name => name, :subjectid => subjectid)
  @model.update :web_uri => url_for("/model/#{@model.id}", :full), :warnings => ""
  task = OpenTox::Task.create("Toxcreate Task - Uploading dataset and creating lazar model",url_for("/models",:full)) do |task|

    task.progress(5)
    @model.update :status => "Uploading and saving dataset", :task_uri => task.uri

    unless params[:dataset] and params[:prediction_feature]
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
          if @dataset.metadata[OT.Errors]
            raise "Incorrect file format. Please follow the instructions for #{link_to "Excel", "/help"} or #{link_to "CSV", "/help"} formats."
          end
        when ".sdf"
          sdf = params[:file][:tempfile].read
          @dataset.load_sdf(sdf, subjectid)
        else
          raise "#{params[:file][:filename]} has an unsupported file type."
        end
        @dataset.save(subjectid)
      rescue => e
        error "Dataset creation failed '#{e.message}'",e
      end
      if @dataset.features.keys.size != 1
        error "More than one feature in dataset #{params[:file][:filename]}. Please delete irrelvant columns and try again."
      else
        @prediction_feature = OpenTox::Feature.find(@dataset.features.keys.first,subjectid)
      end
    end

    task.progress(10)
    if @dataset.compounds.size < 10
      error "Too few compounds to create a prediction model. Did you provide compounds in SMILES format and classification activities as described in the #{link_to "instructions", "/help"}? As a rule of thumb you will need at least 100 training compounds for nongeneric datasets. A lower number could be sufficient for congeneric datasets."
    end
    @model.update :training_dataset => @dataset.uri, :nr_compounds => @dataset.compounds.size, :status => "Creating prediction model"
    @model.update :warnings => @dataset.metadata[OT.Warnings] unless @dataset.metadata[OT.Warnings] and @dataset.metadata[OT.Warnings].empty?
    task.progress(15)
    begin
      lazar = OpenTox::Model::Lazar.create( {:dataset_uri => @dataset.uri, :prediction_feature => @prediction_feature.uri, :subjectid => subjectid}, 
        OpenTox::SubTask.new(task,15,25))
    rescue => e
      error "Model creation failed",e # Please check if the input file is in a valid #{link_to "Excel", "/help"} or #{link_to "CSV", "/help"} format."
    end
=begin
    type = "unknown"
    if lazar.metadata[RDF.type].grep(/Classification/)
      type = "classification"
    elsif lazar.metadata[RDF.type].grep(/Regression/)
      type = "regression"
    end
=end
    @model.update :type => @prediction_feature.feature_type, :feature_dataset => lazar.metadata[OT.featureDataset], :uri => lazar.uri

    if CONFIG[:services]["opentox-validation"]
      @model.update :status => "Validating model"
      begin
        crossvalidation = OpenTox::Crossvalidation.create( {
            :algorithm_uri => lazar.metadata[OT.algorithm],
            :dataset_uri => lazar.parameter("dataset_uri"),
            :subjectid => subjectid,
            :prediction_feature => lazar.parameter("prediction_feature"),
            :algorithm_params => "feature_generation_uri=#{lazar.parameter("feature_generation_uri")}" },
            nil, OpenTox::SubTask.new(task,25,80))

        @model.update(:validation_uri => crossvalidation.uri)
        LOGGER.debug "Validation URI: #{@model.validation_uri}"

        # create summary
        validation = crossvalidation.statistics(subjectid)
        @model.update(:nr_predictions => validation.metadata[OT.numInstances].to_i - validation.metadata[OT.numUnpredicted].to_i)
        if validation.metadata[OT.classificationStatistics]
          @model.update(:correct_predictions => validation.metadata[OT.classificationStatistics][OT.percentCorrect].to_f)
          @model.update(:confusion_matrix => validation.confusion_matrix.to_yaml)
          #@model.update(:weighted_area_under_roc => validation.metadata[OT.classificationStatistics][OT.weightedAreaUnderRoc].to_f)
          @model.update(:weighted_area_under_roc => validation.metadata[OT.classificationStatistics][OT.averageAreaUnderRoc].to_f)
          validation.metadata[OT.classificationStatistics][OT.classValueStatistics].each do |m|
            if m[OT.classValue] =~ TRUE_REGEXP
              #HACK: estimate true feature value correctly 
              @model.update(:sensitivity => m[OT.truePositiveRate])
              @model.update(:specificity => m[OT.trueNegativeRate])
              break
            end
          end
        else
          @model.update(:r_square => validation.metadata[OT.regressionStatistics][OT.rSquare].to_f)
          @model.update(:root_mean_squared_error => validation.metadata[OT.regressionStatistics][OT.rootMeanSquaredError].to_f)
          @model.update(:mean_absolute_error => validation.metadata[OT.regressionStatistics][OT.meanAbsoluteError].to_f)
        end
      rescue => e
        @model.update :warnings => @model.warnings.to_s+"\nModel crossvalidation failed with #{e.message}."
        error "Model validation failed",e
      end
    
      begin
        @model.update :status => "Creating validation report"
        validation_report_uri = crossvalidation.find_or_create_report(subjectid, OpenTox::SubTask.new(task,80,90)) #unless @model.dirty?
        @model.update :validation_report_uri => validation_report_uri, :status => "Creating QMRF report"
        qmrf_report = OpenTox::Crossvalidation::QMRFReport.create(@model.uri, subjectid, OpenTox::SubTask.new(task,90,99))
        @model.update(:validation_qmrf_uri => qmrf_report.uri, :status => "Completed")
      rescue => e
        error "Model report creation failed",e
      end
    else
      @model.update(:status => "Completed") #, :warnings => @model.warnings + "\nValidation service cannot be accessed from localhost.")
      task.progress(99)
    end
    lazar.uri
  end
  @model.update :task_uri => task.uri
  sleep 0.25 # power nap: ohm sometimes returns nil values for model.status or for model itself
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
    lazar = OpenTox::Model::Lazar.find model.uri
    prediction_dataset_uri = lazar.run({:compound_uri => @compound.uri, :subjectid => subjectid})
    LOGGER.debug "Prediction dataset_uri: #{prediction_dataset_uri}"
    if lazar.value_map
      @value_map = lazar.value_map
    else
      @value_map = nil
    end
    prediction_dataset = OpenTox::LazarPrediction.find(prediction_dataset_uri, subjectid)
    if prediction_dataset.metadata[OT.hasSource].match(/dataset/)
      @predictions << {
        :title => model.name,
        :measured_activities => prediction_dataset.measured_activities(@compound)
      }
    else
      predicted_feature = prediction_dataset.metadata[OT.dependentVariables]
      prediction = OpenTox::Feature.find(predicted_feature, subjectid)
      if prediction.metadata[OT.error]
        @predictions << {
          :title => model.name,
          :error => prediction.metadata[OT.error]
          }
      elsif prediction_dataset.value(@compound).nil?
        @predictions << {
          :title => model.name,
          :error => "Not enough similar compounds in training dataset."
          }
      else
        @predictions << {
          :title => model.name,
          :model_uri => model.uri,
          :prediction => prediction_dataset.value(@compound),
          :confidence => prediction_dataset.confidence(@compound)
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
  lazar = OpenTox::Model::Lazar.find @model_uri
  prediction_dataset_uri = lazar.run(:compound_uri => params[:compound_uri], :subjectid => session[:subjectid])
  if lazar.value_map
    @value_map = lazar.value_map
  else
    @value_map = nil
  end
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
