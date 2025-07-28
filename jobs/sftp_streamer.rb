require 'net/sftp'
require 'aws-sdk-s3'
require 'logger'
require 'stringio'

class SftpStreamer
  include Sidekiq::Job
  sidekiq_options retry: 3

  def perform(s3_object_key)
    logger = Logger.new(STDOUT)
    sftp_filename = File.basename(s3_object_key)
    remote_path = "upload/#{sftp_filename}"


    logger.info "Starting SFTP stream for #{s3_object_key}"

    Net::SFTP.start('localhost', 'testuser', password: 'password', port: 2222) do |sftp|
      logger.info "Connected to SFTP server."
      
      sftp.upload!(s3_stream(s3_object_key, logger), remote_path)
      
      logger.info "Successfully streamed #{sftp_filename} to SFTP server at #{remote_path}"
    end
  rescue StandardError => e
    logger.error "SFTP stream failed for #{s3_object_key}: #{e.message}"
    raise e
  end

  private

  def s3_client
    Aws::S3::Client.new(
      access_key_id: 'minioadmin',
      secret_access_key: 'minioadmin',
      endpoint: 'http://localhost:9000',
      region: 'us-east-1',
      force_path_style: true
    )
  end

  def s3_stream(object_key, logger)
    bucket_name = 'payment-exports'
    string_io = StringIO.new

    logger.info "Streaming from s3://#{bucket_name}/#{object_key}"
    
    s3_client.get_object(bucket: bucket_name, key: object_key) do |chunk|
      string_io.write(chunk)
    end
    
    string_io.rewind
    string_io
  end
end