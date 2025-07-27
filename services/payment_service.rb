# services/payment_service.rb
class PaymentService
    # Returns all payments
    def self.list
      { success: true, payments: Payment.all }
    end
  
    # Creates a new payment from a hash of parameters
    def self.create(params)
      payment = Payment.new(params)
      if payment.save
        { success: true, payment: payment }
      else
        { success: false, errors: payment.errors.full_messages }
      end
    rescue => e
      # Catch any other unexpected errors during creation
      { success: false, errors: [e.message] }
    end
  end
  