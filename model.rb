require 'ohm'
#require 'redis/objects'
#@@redis = Redis.new(:thread_safe=>true)#(:host => '127.0.0.1', :port => 6379)

class ToxCreateModel < Ohm::Model

  #include Redis::Objects
	#include DataMapper::Resource
	#attribute :id
	attribute :name
	attribute :warnings
	attribute :error_messages
	attribute :type
  attribute :status
	attribute :created_at

	attribute :task_uri
	attribute :uri

	attribute :training_dataset
	attribute :feature_dataset
	#attributey :validation_task_uri
	attribute :validation_uri

	#attributey :validation_report_task_uri
	attribute :validation_report_uri

	#attributey :validation_qmrf_task_uri
	attribute :validation_qmrf_uri

	attribute :nr_compounds
	attribute :nr_predictions
	attribute :true_positives
	attribute :false_positives
	attribute :true_negatives
	attribute :false_negatives
	attribute :correct_predictions
	attribute :weighted_area_under_roc
	attribute :sensitivity
	attribute :specificity
	attribute :r_square
	attribute :root_mean_squared_error
	attribute :mean_absolute_error

  attribute :web_uri

  attr_accessor :subjectid
  @subjectid = nil

  #after :save, :check_policy

=begin
  attr_accessor :id, :name, :warnings, :error_messages, :type, :status, :created_at, :task_uri, :uri, :training_dataset, :feature_dataset, :validation_task_uri, :validation_uri, :validation_report_task_uri, :validation_report_uri, :validation_qmrf_task_uri, :validation_qmrf_uri, :nr_compounds, :nr_predictions, :true_positives, :false_positives, :true_negatives, :false_negatives, :correct_predictions, :weighted_area_under_roc, :sensitivity, :specificity, :r_square, :root_mean_squared_error, :mean_absolute_error, :web_uri

  def self.all
  end

  def self.get(id)
  end
  
  def self.create(params)
    @id = @@redis.incr "toxcreate"
    params.each { |k,v| @@redis.hset "toxcreate:#{@id}", k, v }
    self.get(@id)
  end

  def update(params)
  end

  def method_missing
    begin
    rescue
      raise "Unknown method"
    end
  end

  attr_accessor :subjectid
  @subjectid = nil

  after :save, :check_policy

def status
		#begin
			RestClient.get(File.join(@task_uri, 'hasStatus')).body
		#rescue
		#	"Service offline"
		#end
	end
=end
=begin

	def validation_status
		begin
			RestClient.get(File.join(@validation_task_uri, 'hasStatus')).body
		rescue
			"Service offline"
		end
	end

	def validation_report_status
		begin
			RestClient.get(File.join(@validation_report_task_uri, 'hasStatus')).body
		rescue
			"Service offline"
		end
	end

	def validation_qmrf_status
		begin
			RestClient.get(File.join(@validation_qmrf_task_uri, 'hasStatus')).body
		rescue
			"Service offline"
		end
	end

	def algorithm
		begin
			RestClient.get(File.join(@uri, 'algorithm')).body
		rescue
			""
		end
	end

	def training_dataset
		begin
			RestClient.get(File.join(@uri, 'trainingDataset')).body
		rescue
			""
		end
	end

	def feature_dataset
		begin
			RestClient.get(File.join(@uri, 'feature_dataset')).body
		rescue
			""
		end
	end

  def process

    LOGGER.debug self.to_yaml

    if @uri.nil? and status == "Completed"
			#update :uri => RestClient.get(File.join(@task_uri, 'resultURI')).body
			#lazar = YAML.load(RestClient.get(@uri, :accept => "application/x-yaml").body)

		elsif @validation_uri.nil? and validation_status == "Completed"
			begin

				#update :validation_uri => RestClient.get(File.join(@validation_task_uri, 'resultURI')).body
				#LOGGER.debug "Validation URI: #{@validation_uri}"

				#update :validation_report_task_uri => RestClient.post(File.join(CONFIG[:services]["opentox-validation"],"/report/crossvalidation"), :validation_uris => @validation_uri).body
				#LOGGER.debug "Validation Report Task URI: #{@validation_report_task_uri}"

				#update :validation_qmrf_task_uri => RestClient.post(File.join(CONFIG[:services]["opentox-validation"],"/reach_report/qmrf"), :model_uri => @uri).body
				#LOGGER.debug "QMRF Report Task URI: #{@validation_qmrf_task_uri}"

        uri = File.join(@validation_uri, 'statistics')
        yaml = RestClient.get(uri).body
        v = YAML.load(yaml)

        case type
        when "classification"
          tp=0; tn=0; fp=0; fn=0; n=0
          v[:classification_statistics][:confusion_matrix][:confusion_matrix_cell].each do |cell|
            if cell[:confusion_matrix_predicted] == "true" and cell[:confusion_matrix_actual] == "true"
              tp = cell[:confusion_matrix_value]
              n += tp
            elsif cell[:confusion_matrix_predicted] == "false" and cell[:confusion_matrix_actual] == "false"
              tn = cell[:confusion_matrix_value]
              n += tn
            elsif cell[:confusion_matrix_predicted] == "false" and cell[:confusion_matrix_actual] == "true"
              fn = cell[:confusion_matrix_value]
              n += fn
            elsif cell[:confusion_matrix_predicted] == "true" and cell[:confusion_matrix_actual] == "false"
              fp = cell[:confusion_matrix_value]
              n += fp
            end
          end
          update :nr_predictions => n
          update :true_positives => tp
          update :false_positives => fp
          update :true_negatives => tn
          update :false_negatives => fn
          update :correct_predictions => 100*(tp+tn).to_f/n
          update :weighted_area_under_roc => v[:classification_statistics][:weighted_area_under_roc].to_f
          update :sensitivity => tp.to_f/(tp+fn)
          update :specificity => tn.to_f/(tn+fp)
        when "regression"
          update :nr_predictions => v[:num_instances] - v[:num_unpredicted]
          update :r_square => v[:regression_statistics][:r_square]
          update :root_mean_squared_error => v[:regression_statistics][:root_mean_squared_error]
          update :mean_absolute_error => v[:regression_statistics][:mean_absolute_error]
        end
			rescue
				LOGGER.warn "Cannot create Validation Report Task #{@validation_report_task_uri} for  Validation URI #{@validation_uri} from Task #{@validation_task_uri}"
			end

		else

      if @validation_report_uri.nil? and validation_report_status == "Completed"
        begin
          update :validation_report_uri => RestClient.get(File.join(@validation_report_task_uri, 'resultURI')).body
        rescue
          LOGGER.warn "Cannot create Validation Report for  Task URI #{@validation_report_task_uri} "
        end
      end

      if @validation_qmrf_uri.nil? and validation_qmrf_status == "Completed"
        begin
          update :validation_qmrf_uri => RestClient.get(File.join(@validation_qmrf_task_uri, 'resultURI')).body
        rescue
          LOGGER.warn "Cannot create QMRF Report for  Task URI #{@validation_qmrf_task_uri} "
        end
      end

    end

  end
=end

  private
  def check_policy
    OpenTox::Authorization.check_policy(web_uri, subjectid)
  end

end

#DataMapper.auto_upgrade!
