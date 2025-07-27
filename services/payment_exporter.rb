# services/payment_exporter.rb
class PaymentExporter
  def self.call
    # Find payments that are 'pending' and belong to an active company
    payments_to_export = Payment.where(status: :pending)
                                  .joins(:company)
                                  .where(companies: { active: true })

    return { success: true, message: 'No pending payments to export.' } if payments_to_export.empty?

    job = nil
    ActiveRecord::Base.transaction do
      # 1. Create a new job record
      job = Job.create!

      # 2. "Claim" the payments by updating their status and associating them with the new job
      payments_to_export.update_all(status: 'exporting', job_id: job.id)
    end

    # In a real application, you would now trigger a background worker with the job.id
    {
      success: true,
      message: "Job created to export #{payments_to_export.count} payments.",
      job: job
    }
  rescue => e
    { success: false, message: "An error occurred: #{e.message}" }
  end
end
