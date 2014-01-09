require 'singleton'
require 'aws-sdk'
require 'bot_config'

class BotAWS
  include Singleton

  def initialize
    AWS.config({
    :access_key_id => BotConfig.aws_access_key_id,
    :secret_access_key => BotConfig.aws_access_secret_key,
    })
    @s3 = AWS::S3.new
  end

  def upload_build(bot)
    key = File.basename(file_name)
    s3.buckets[bucket_name].objects[key].write(:file => file_name)
    puts "Uploading file #{file_name} to bucket #{bucket_name}."
  end
end
