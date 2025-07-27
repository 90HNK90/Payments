require 'date'
# --- FIX: Load the base class this validator inherits from ---
require_relative 'base_validator'

# This handles the basic validation for all companies by default.
# It checks for structural integrity and enforces core business rules for each payment.
module Validators
  class DefaultValidator < BaseValidator
    def validate
      company_id = params['company_id']
      batch_id = params['company_id']
      payments = params['payments']

      # 1. Validate top-level structure and company status
      validate_company(company_id)

      if batch_id.blank?
        @errors << 'Request must include a batch_id.'
      end

      @errors << 'Request must include a non-empty payments array.' unless payments.is_a?(Array) && payments.any?

      # If the basic structure or company is invalid, stop here to avoid unnecessary processing.
      return if @errors.any?

      # 2. Validate each payment record in the array
      payments.each_with_index do |p, i|
        validate_payment(p, i + 1)
      end

      @errors.empty?
    end

    private

    def validate_company(company_id)
      if company_id.blank?
        @errors << 'Request must include a company_id.'
        return
      end

      # Rule: Query the database to ensure the company exists and is active.
      unless Company.exists?(id: company_id, active: true)
        @errors << "Company with id=#{company_id} was not found or is not active."
      end
    end

    def validate_payment(payment, index)
      # Rule: amount_cents must be > 0
      unless payment['amount_cents'].is_a?(Integer) && payment['amount_cents'] > 0
        @errors << "Payment ##{index}: amount_cents must be an integer greater than 0."
      end

      # Rule: BSB must be 6 digits
      unless payment['bank_bsb']&.match?(/\A\d{6}\z/)
        @errors << "Payment ##{index}: bank_bsb must be exactly 6 digits."
      end

      # Rule: Account number must be 6-9 digits
      unless payment['bank_account']&.match?(/\A\d{6,9}\z/)
        @errors << "Payment ##{index}: bank_account must be between 6 and 9 digits."
      end

      # Rule: Currency must be "AUD"
      if payment['currency'] != 'AUD'
        @errors << "Payment ##{index}: currency must be 'AUD'."
      end

      # Rule: Pay date must be today or later
      validate_pay_date(payment['pay_date'], index)
    end

    def validate_pay_date(date_str, index)
      if date_str.blank?
        @errors << "Payment ##{index}: pay_date is missing."
        return
      end

      begin
        pay_date = Date.parse(date_str)
        if pay_date < Date.today
          @errors << "Payment ##{index}: pay_date cannot be in the past."
        end
      rescue Date::Error
        @errors << "Payment ##{index}: pay_date is not a valid date format."
      end
    end
  end
end
