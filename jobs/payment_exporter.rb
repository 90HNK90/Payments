require 'csv'
require 'logger'
require 'fileutils'
require 'aws-sdk-s3'
require_relative 'sftp_streamer'

class PaymentExporter
  include Sidekiq::Job # Changed to use the modern Sidekiq::Job syntax
  sidekiq_options retry: true, unique: :until_executed

  def perform
    logger = Logger.new(STDOUT)
    export_dir = File.join(Dir.pwd, 'tmp', 'exports')
    FileUtils.mkdir_p(export_dir)

    timestamp = Time.now.strftime('%Y%m%d%H%M%S')
    local_file_path = File.join(export_dir, "payments_#{timestamp}.txt")
    s3_object_key = "payments/payments_#{timestamp}.txt" # Path within the S3 bucket

    total_payments_processed = 0
    job_record = nil # Renamed from 'job' to avoid conflict

    begin
      # The entire process, including file generation, S3 upload, and job queuing,
      # is wrapped in a single database transaction for atomicity.
      ActiveRecord::Base.transaction do
        job_record = Job.create!(status: 'pending', executed_at: Time.now)

        CSV.open(local_file_path, 'wb', col_sep: ', ') do |csv|
          csv << ['COMPANY_ID', 'EMPLOYEE_ID', 'BSB', 'ACCOUNT', 'AMOUNT_CENTS', 'CURRENCY', 'PAY_DATE']

          Payment.where(status: 'pending').where('pay_date <= ?', Date.today).lock(true).find_in_batches do |batch|
            batch.each do |payment|
              csv << [
                payment.company_id, payment.employee_id, payment.bsb,
                payment.account, payment.amount_cents, payment.currency, payment.pay_date
              ]
            end
            
            payment_ids = batch.map(&:id)
            Payment.where(id: payment_ids).update_all(status: 'exported', job_id: job_record.id)
            total_payments_processed += batch.size
          end
        end

        if total_payments_processed > 0
          # --- Operations now inside the transaction ---
          # WARNING: Placing network calls (like S3 uploads) inside a database
          # transaction can hold database locks for an extended period, which may
          # impact performance. This approach prioritizes atomicity over minimizing
          # transaction time.

          # 1. Upload the generated file to our local S3 (MinIO)
          upload_to_s3(local_file_path, s3_object_key, logger)

          # 2. Enqueue the SFTP streamer job directly.
          SftpStreamer.perform_async(s3_object_key)

          logger.info "Enqueued SFTP transfer for #{s3_object_key}"
          # The status remains 'pending'. The SftpStreamer is now responsible for the final status update.
          job_record.update!(status: 'success', output: s3_object_key)
        else
          job_record.update!(status: 'success')
        end
      end # The transaction commits here ONLY if all steps inside were successful.

    rescue StandardError => e
      # If an error occurred anywhere inside the transaction (DB, S3 upload, etc.),
      # the entire transaction is automatically rolled back. This means the Job
      # record is deleted and Payment statuses are reverted.
      job_record&.update(status: 'failed', output: e.message)
      logger.error "Payment export transaction failed and was rolled back: #{e.message}"
      raise e # Re-raise for Sidekiq's retry mechanism.
    ensure
      # Clean up the local file regardless of success or failure,
      # as it has either been uploaded or the process failed.
      FileUtils.rm_f(local_file_path)
    end
  end

  private

  def s3_client
    Aws::S3::Client.new(
      access_key_id: 'minioadmin',
      secret_access_key: 'minioadmin',
      endpoint: 'http://localhost:9000',
      region: 'us-east-1', # region is required, but can be anything for MinIO
      force_path_style: true # IMPORTANT for local dev
    )
  end

  def upload_to_s3(file_path, object_key, logger)
    bucket_name = 'payment-exports'
    client = s3_client

    # Ensure the bucket exists
    begin
      client.head_bucket(bucket: bucket_name)
    rescue Aws::S3::Errors::NotFound
      client.create_bucket(bucket: bucket_name)
      logger.info "Created S3 bucket: #{bucket_name}"
    end

    File.open(file_path, 'rb') do |file|
      client.put_object(bucket: bucket_name, key: object_key, body: file)
    end
    logger.info "Successfully uploaded #{file_path} to s3://#{bucket_name}/#{object_key}"
  end
end