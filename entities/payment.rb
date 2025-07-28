class Payment < ActiveRecord::Base
  belongs_to :company
  belongs_to :job, optional: true

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
end
