# This registry maps a company ID to its specific validation class.
require_relative 'default_validator'
require_relative 'company_with_reference_validator'
module Validators
  class Registry
    # Register company-specific validators here.
    # Key: company_id (string)
    # Value: Validator Class
    COMPANY_SPECIFIC_VALIDATORS = {
      'company_uuid_requiring_reference' => Validators::CompanyWithReferenceValidator
    }.freeze

    # Returns the appropriate validator class for a given company_id.
    # Falls back to the DefaultValidator if no specific one is found.
    def self.for(company_id)
      COMPANY_SPECIFIC_VALIDATORS.fetch(company_id, Validators::DefaultValidator)
    end
  end
end