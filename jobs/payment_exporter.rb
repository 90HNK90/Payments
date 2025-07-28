require 'csv'
require 'logger'
require 'fileutils'
require 'aws-sdk-s3'
require_relative 'sftp_streamer'

class PaymentExporter
  include Sidekiq::Job
  sidekiq_options retry: true, unique: :until_executed

  def perform
    logger = Logger.new(STDOUT)
    export_dir = File.join(Dir.pwd, 'tmp', 'exports')
    FileUtils.mkdir_p(export_dir)

    timestamp = Time.now.strftime('%Y%m%d%H%M%S')
    local_file_path = File.join(export_dir, "payments_#{timestamp}.txt")
    s3_object_key = "payments/payments_#{timestamp}.txt"

    total_payments_processed = 0
    job_record = nil

    begin
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
          upload_to_s3(local_file_path, s3_object_key, logger)

          SftpStreamer.perform_async(s3_object_key)

          logger.info "Enqueued SFTP transfer for #{s3_object_key}"
          job_record.update!(status: 'success', output: s3_object_key)
        else
          job_record.update!(status: 'success')
        end
      end
    rescue StandardError => e
      job_record&.update(status: 'failed', output: e.message)
      logger.error "Payment export transaction failed and was rolled back: #{e.message}"
    ensure
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