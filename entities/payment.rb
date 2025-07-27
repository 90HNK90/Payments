# entities/payment.rb
# Corresponds to the 'payments' table.
class Payment < ActiveRecord::Base
  # A payment belongs to one company.
  belongs_to :company

  # A payment can optionally belong to a job.
  # `optional: true` is required because the `job_id` foreign key can be NULL.
  belongs_to :job, optional: true

  # Defines enums for the custom currency and status types.
  enum currency: {
    AUD: 'AUD',
    USD: 'USD',
    SGD: 'SGD',
    VND: 'VND'
  }

  enum status: {
    pending: 'pending',
    exporting: 'exporting',
    exported: 'exported'
  }

  # You could add validations here to match your schema constraints:
  # validates :employee_id, presence: true
  # validates :bsb, presence: true, length: { is: 6 }
  # validates :account, presence: true, length: { is: 9 }
  # validates :pay_date, presence: true
end
