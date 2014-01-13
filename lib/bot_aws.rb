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
      puts "Amazon access keys missing."
      return
    end

    AWS.config({
      :access_key_id => aws_access_key_id,
      :secret_access_key => aws_access_secret_key,
    })
    @s3 = AWS::S3.new
  end

  def upload_build(bot, upload_bucket, branch_name)
    s3_bucket = @s3.buckets[upload_bucket]
    if ( ! s3_bucket.exists?)
      puts "S3 bucket \"#{upload_bucket}\" does not exist."
      return
    end

    file_name = "/Library/Server/Xcode/Data/BotRuns/BotRun-#{bot.latestSuccessfulBotRunGUID}.bundle/output/#{bot.long_name}.ipa"
    if ( ! File.exists?(file_name))
      puts "File not uploaded. \"#{file_name}\" does not exist."
      return
    end

    company_name = BotConfig.instance.company_name
    title = BotConfig.instance.aws_upload_name(branch_name)
    version_string = "2.2.0" #TODO figure out where to get this info
    bundle_identifier = BotConfig.instance.aws_upload_bundle_identifier(branch_name)
    list_versions = BotConfig.instance.aws_upload_list_versions(branch_name)

    if (list_versions)
      key_prefix = "#{title}-#{version_string}"
    else
      key_prefix = title
    end

    if (s3_bucket.objects["#{key_prefix}.plist"].exists?)
      return # Build already uploaded
    end

    # Upload ipa
    s3_bucket.objects["#{key_prefix}.ipa"].write(:file => file_name).acl = :public_read
    puts "Uploaded \"#{file_name}\" to bucket #{upload_bucket}."

    template_path = File.dirname(__FILE__) + "/../templates"

    # Upload plist
    plist_template = IO.read("#{template_path}/plist.template")
    template = Liquid::Template.parse(plist_template)
    ipa_url = "https://#{upload_bucket}.s3.amazonaws.com/#{key_prefix}.ipa"
    plist_string = template.render(
      'ipa_url' => ipa_url,
      'bundle_identifier' => bundle_identifier,
      'version_string' => version_string,
      'title' => title
      )
    s3_bucket.objects["#{key_prefix}.plist"].write(plist_string).acl = :public_read
    puts "Uploaded plist for \"#{key_prefix}\" to bucket #{upload_bucket}."

    # Upload index.html
    builds = []
    if (list_versions) # List each plist found in the bucket
      s3_bucket.objects.each do |object|
        if (object.key.end_with?('plist'))
          url = "https://#{upload_bucket}.s3.amazonaws.com/#{object.key}"
          build = {'url' => url, 'title' => object.key.sub('.plist', '')}
          builds << build
        end
      end
    else # Only list plist that was just uploaded
      build = {'url' => ipa_url, 'title' => title}
      builds << build
    end
    html_template = IO.read("#{template_path}/html.template")
    template = Liquid::Template.parse(html_template)
    html_string = template.render('company_name' => company_name, 'builds' => builds)
    html_name = BotConfig.instance.aws_upload_html_name(branch_name)
    html_file_name = (html_name ? html_name : 'index')
    s3_bucket.objects["#{html_file_name}.html"].write(html_string).acl = :public_read
    puts "Uploaded index.html to bucket #{upload_bucket}."
  end
end
