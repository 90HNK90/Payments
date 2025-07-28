require_relative 'default_validator'
require_relative 'company_with_reference_validator'
module Validators
  class Registry
    COMPANY_SPECIFIC_VALIDATORS = {
      'company_uuid_requiring_reference' => Validators::CompanyWithReferenceValidator
    }.freeze

    def self.for(company_id)
      COMPANY_SPECIFIC_VALIDATORS.fetch(company_id, Validators::DefaultValidator)
    end
  end
end