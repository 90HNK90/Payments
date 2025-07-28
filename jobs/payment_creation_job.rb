# jobs/payment_creation_job.rb
require 'sidekiq'
require 'securerandom'
require 'logger'

class PaymentCreationJob
  include Sidekiq::Job
  INSERT_BATCH_SIZE = 1000

  def perform(payload)
    transformed_payments = payload['transformed_payments']
    callback_url = payload['callback_url']
    batch_id = payload['batch_id']
    company_id = payload['company_id']
    original_payments = payload['original_payments']
    total_payments = transformed_payments.size
    logger = Logger.new(STDOUT)
    logger.info "Starting to process a batch of #{total_payments} payments for batch_id: #{batch_id}."
    timestamp = Time.now

    ActiveRecord::Base.transaction do
      transformed_payments.each_slice(INSERT_BATCH_SIZE) do |batch|
        batch.each do |attrs|
          attrs['id'] ||= SecureRandom.uuid
          attrs['batch_id']=batch_id
          attrs['created_at'] ||= timestamp
          attrs['updated_at'] ||= timestamp
        end
        logger.info "insert batch size: #{batch.size}"
        Payment.insert_all!(batch)
      end
    end

    logger.info "Successfully inserted #{total_payments} payments for batch_id: #{batch_id}."

    if callback_url.present?
      logger.info "Sending asynchronous webhook notification for batch_id: #{batch_id} to #{callback_url}"
    end
  rescue => e
    logger.error "Transaction failed for batch_id: #{batch_id}. All inserts have been rolled back. Reason: #{e.message}"
    raise e
  end
end
