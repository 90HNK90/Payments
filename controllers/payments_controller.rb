class PaymentsController < Sinatra::Base
  post '/payments/trigger' do
    PaymentBatchService.trigger()
    { success: true, status: 202, message: "Triggered" }.to_json
  end

  post '/payments' do
    begin
      request_params = JSON.parse(request.body.read)
      result = PaymentBatchService.create(request_params)

      if result[:success]
        status result[:status]
        { message: result[:message] }.to_json
      else
        halt result[:status], { message: 'Bad Request', errors: result[:errors] }.to_json
      end
    rescue JSON::ParserError
      halt 400, { message: 'Invalid JSON' }.to_json
    end
  end
end
