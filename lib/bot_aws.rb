require 'singleton'
require 'aws-sdk'
require 'bot_config'
require 'liquid'

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

  def upload_build(bot, upload_bucket)
    file_name = "/Library/Server/Xcode/Data/BotRuns/BotRun-#{bot.latestSuccessfulBotRunGUID}.bundle/output/#{bot.long_name}.ipa"
    if (File.exists?(file_name))
      s3_bucket = @s3.buckets[upload_bucket]
      if (s3_bucket.exists?)
        company_name = 'Matchbook' #TODO figure out where to get this info
        title = "Matchbook" #TODO figure out where to get this info
        version_string = "2.2.0" #TODO figure out where to get this info
        bundle_identifier = "co.matchbookit.matchbook" #TODO figure out where to get this info
        key_prefix = "#{title}-#{version_string}"

        s3_bucket.objects["#{key_prefix}.ipa"].write(:file => file_name)
        puts "Uploaded \"#{file_name}\" to bucket #{upload_bucket}."

        #template_path = File.expand_path(File.dirname(__FILE__) + "/../templates")
        template_path = File.dirname(__FILE__) + "/../templates"

        plist_template = IO.read("#{template_path}/plist.template")
        template = Liquid::Template.parse(plist_template)
        ipa_url = "https://#{upload_bucket}.s3.amazonaws.com/#{key_prefix}.ipa"
        plist_string = template.render(
          'ipa_url' => ipa_url,
          'bundle_identifier' => bundle_identifier,
          'version_string' => version_string,
          'title' => title
          )
        s3_bucket.objects["#{key_prefix}.plist"].write(plist_string)
        puts "Uploaded plist for \"#{key_prefix}\" to bucket #{upload_bucket}."

        builds = []
        s3_bucket.objects.each do |object|
          if (object.key.end_with?('plist'))
            url = "https://#{upload_bucket}.s3.amazonaws.com/#{object.key}"
            build = {'url' => url, 'title' => object.key.sub('plist', '')}
            builds << build
          end
        end
        html_template = IO.read("#{template_path}/html.template")
        template = Liquid::Template.parse(html_template)
        html_string = template.render('company_name' => company_name, 'builds' => builds)
        s3_bucket.objects['index.html'].write(html_string)
        puts "Uploaded index.html to bucket #{upload_bucket}."
      elsif
        puts "S3 bucket \"#{upload_bucket}\" does not exist."
      end
    else
      puts "File not uploaded. \"#{file_name}\" does not exist."
    end
  end

end
