# An example of a company-specific validator that inherits default rules.
module Validators
    class CompanyWithReferenceValidator < DefaultValidator
      def validate
        # Run all the checks from the DefaultValidator first.
        super
  
        # Now add this company's specific rules.
        params['payments']&.each_with_index do |payment, index|
          if payment['reference'].blank?
            @errors << "Payment ##{index + 1}: A 'reference' field is required for this company."
          end
        end
  
        @errors.empty?
      end
    end
  end