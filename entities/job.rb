class Job < ActiveRecord::Base
  self.table_name = 'job'
  has_many :payments

  enum status: {
    pending: 'pending',
    success: 'success',
    failed: 'failed'
  }
end
