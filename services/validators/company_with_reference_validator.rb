module Validators
    class CompanyWithReferenceValidator < DefaultValidator
      def validate
        super
  
        params['payments']&.each_with_index do |payment, index|
          if payment['reference'].blank?
            @errors << "Payment ##{index + 1}: A 'reference' field is required for this company."
          end
        end
  
        @errors.empty?
      end
    end
  end