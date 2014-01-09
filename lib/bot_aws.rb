require 'singleton'
require 'aws-sdk'
require 'bot_config'

class BotAWS
  include Singleton

  def initialize
    aws_access_key_id = BotConfig.instance.aws_access_key_id
    aws_access_secret_key = BotConfig.instance.aws_access_secret_key
    if ( ! aws_access_key_id || ! aws_access_secret_key)
      $stderr.puts "Amazon access keys missing."
      PP.pp("Amazon access keys missing.", STDERR)
      exit 1
    end

    AWS.config({
      :access_key_id => aws_access_key_id,
      :secret_access_key => aws_access_secret_key,
    })
    @s3 = AWS::S3.new
  end

  def upload_build(bot)
    key = File.basename(file_name)
    s3.buckets[bucket_name].objects[key].write(:file => file_name)
    puts "Uploading file #{file_name} to bucket #{bucket_name}."
  end
  
end
