module Validators
  class BaseValidator
    attr_reader :params, :errors

    def initialize(request_params)
      @params = request_params
      @errors = []
    end

    def validate
      raise NotImplementedError, "#{self.class.name} must implement the 'validate' method."
    end

    def success?
      validate if @errors.empty?
      @errors.empty?
    end
  end
end