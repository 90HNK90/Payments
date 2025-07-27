# controllers/payments_controller.rb
class PaymentsController < Sinatra::Base
  # GET /payments - List all payments (remains synchronous)
  post '/payments/trigger' do
    PaymentBatchService.trigger()
    { success: true, status: 202, message: "Triggered" }.to_json
  end

  # POST /payments - Accepts a BATCH of payments for asynchronous processing
  post '/payments' do
    begin
      request_params = JSON.parse(request.body.read)
      # Use the new batch service
      result = PaymentBatchService.create(request_params)

      if result[:success]
        status result[:status] # e.g., 202 Accepted
        { message: result[:message] }.to_json
      else
        halt result[:status], { message: 'Bad Request', errors: result[:errors] }.to_json
      end
    rescue JSON::ParserError
      halt 400, { message: 'Invalid JSON' }.to_json
    end
  end
end
