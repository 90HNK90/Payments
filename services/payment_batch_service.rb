# services/payment_batch_service.rb
require_relative 'validators/registry'
require_relative 'validators/base_validator'
require_relative 'validators/default_validator'
require_relative 'validators/company_with_reference_validator'

class PaymentBatchService
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
  
  def self.trigger()
    logger.info "Trigger PaymentExporter manually"
    PaymentExporter.perform_async()
  end  
  
  def self.create(request_params)
    company_id = request_params['company_id']
    validator_class = ::Validators::Registry.for(company_id)
    validator = validator_class.new(request_params)

    unless validator.success?
      return { success: false, status: 400, errors: validator.errors }
    end

    payments_data = request_params['payments']
    batch_id = request_params['batch_id']
    callback_url = request_params['callback_url']

    transformed_payments = payments_data.map do |payment|
      {
        "company_id"   => company_id,
        "employee_id"  => payment['employee_id'],
        "bsb"          => payment['bank_bsb'],
        "account"      => payment['bank_account'],
        "amount_cents" => payment['amount_cents'],
        "currency"     => payment['currency'],
        "pay_date"     => payment['pay_date']
      }
    end

    job_payload = {
      "company_id"           => company_id,
      "batch_id"             => batch_id,
      "callback_url"         => callback_url,
      "transformed_payments" => transformed_payments,
      "original_payments"    => payments_data
    }
    PaymentCreationJob.perform_async(job_payload)
    logger.info "[API] Enqueued job for #{transformed_payments.size} payments for company #{company_id}."

    { success: true, status: 201, message: "Accepted: A batch of #{transformed_payments.size} payments has been enqueued for processing." }
  end
end
