# jobs/webhook_notification_job.rb
require 'sidekiq'
require 'net/http'
require 'uri'
require 'json'

# This job is solely responsible for sending an outbound webhook notification.
# It's kept separate from PaymentCreationJob to isolate failures.
class WebhookNotificationJob
  include Sidekiq::Job

  # Configure Sidekiq to retry this job if it fails (e.g., network issues).
  sidekiq_options retry: 5

  def perform(callback_url, payload)
    puts "[Webhook] Sending notification to #{callback_url} with payload: #{payload.to_json}"

    begin
      uri = URI.parse(callback_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      request.body = payload.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        puts "[Webhook] Successfully sent notification. Received status: #{response.code}"
      else
        puts "[Webhook] ERROR: Failed to send notification. Received status: #{response.code}, Body: #{response.body}"
        # This will cause Sidekiq to retry the job based on the retry options.
        raise "Webhook failed with status #{response.code}"
      end
    rescue => e
      puts "[Webhook] CRITICAL ERROR: An exception occurred while sending webhook: #{e.message}"
      # Re-raise the exception to trigger a Sidekiq retry.
      raise e
    end
  end
end
