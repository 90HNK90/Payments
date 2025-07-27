# entities/company.rb
# Corresponds to the 'company' table.
class Company < ActiveRecord::Base
  self.table_name = 'company'
  # A company can have many payments.
  # The `dependent: :restrict_with_error` option prevents a company
  # from being deleted if it has associated payments, matching the
  # default foreign key behavior.
  has_many :payments, dependent: :restrict_with_error

  # You could add validations here, for example:
  # validates :name, presence: true, uniqueness: { scope: :active, if: :active? }
end
