require 'ohm'
require 'ohm/contrib'

class ToxCreateModel < Ohm::Model

  include Ohm::Callbacks
  include Ohm::Typecast
  include Ohm::Timestamping  

	attribute :name
	attribute :warnings
	attribute :error_messages
	attribute :type
  attribute :status
	attribute :created_at, Date

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
  attribute :confusion_matrix
	attribute :nr_compounds
  attribute :nr_predictions
  attribute :correct_predictions
	attribute :average_area_under_roc
	attribute :sensitivity
	attribute :specificity
	attribute :r_square
	attribute :root_mean_squared_error
	attribute :mean_absolute_error

  attribute :web_uri

  attr_accessor :subjectid
  @subjectid = nil

  after :save, :check_policy

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

  private
  def check_policy
    OpenTox::Authorization.check_policy(web_uri, subjectid)
  end

end