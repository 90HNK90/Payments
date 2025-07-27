# This is the base class for all validators.
module Validators
  class BaseValidator
    attr_reader :params, :errors

    def initialize(request_params)
      @params = request_params
      @errors = []
    end

    # Subclasses must implement this method.
    def validate
      raise NotImplementedError, "#{self.class.name} must implement the 'validate' method."
    end

    def success?
      # Run validation if it hasn't been run yet.
      validate if @errors.empty?
      @errors.empty?
    end
  end
end