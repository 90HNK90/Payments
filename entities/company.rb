class Company < ActiveRecord::Base
  self.table_name = 'company'
  has_many :payments, dependent: :restrict_with_error
end
