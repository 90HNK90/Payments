# jobs/payment_creation_job.rb
require 'sidekiq'
require 'securerandom'

class PaymentCreationJob
  include Sidekiq::Job
  INSERT_BATCH_SIZE = 1000

  def perform(payload)
    # Unpack the richer payload
    transformed_payments = payload['transformed_payments']
    callback_url = payload['callback_url']
    batch_id = payload['batch_id']
    company_id = payload['company_id']
    original_payments = payload['original_payments']
    total_payments = transformed_payments.size

    puts "[Sidekiq Worker] Starting to process a batch of #{total_payments} payments for batch_id: #{batch_id}."
    timestamp = Time.now

    ActiveRecord::Base.transaction do
      transformed_payments.each_slice(INSERT_BATCH_SIZE) do |batch|
        batch.each do |attrs|
          attrs['id'] ||= SecureRandom.uuid
          attrs['batch_id']=batch_id
          attrs['created_at'] ||= timestamp
          attrs['updated_at'] ||= timestamp
        end
        Payment.insert_all(batch)
      end
    end

    puts "[Sidekiq Worker] Successfully inserted #{total_payments} payments for batch_id: #{batch_id}."

    # After successful insertion, check for a callback_url.
    if callback_url.present?
      puts "[Sidekiq Worker] Enqueuing webhook notification for batch_id: #{batch_id} to #{callback_url}"
      
      # Construct the notification payload to match the requested format.
      notification_payload = {
        company_id: company_id,
        batch_id: batch_id,
        payments: original_payments
      }
      
      # Enqueue the separate job to handle the HTTP call.
      WebhookNotificationJob.perform_async(callback_url, notification_payload)
    end

  rescue => e
    puts "[Sidekiq Worker] ERROR: Transaction failed for batch_id: #{batch_id}. All inserts have been rolled back. Reason: #{e.message}"
    raise e
  end
end
