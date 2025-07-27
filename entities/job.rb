# entities/job.rb
# Corresponds to the 'job' table.
class Job < ActiveRecord::Base
  self.table_name = 'job'
  # A job can be associated with many payments.
  has_many :payments

  # Defines an enum for the 'status' column. This provides helper methods
  # like `job.pending?`, `job.success!`, etc., and ensures only valid
  # values are used.
  enum status: {
    pending: 'pending',
    success: 'success',
    failed: 'failed'
  }
end
