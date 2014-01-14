require 'singleton'
require 'aws-sdk'
require 'bot_config'
require 'liquid'
require 'git'
require 'zip'

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
      :secret_access_key => aws_access_secret_key
    })
    @s3 = AWS::S3.new
  end

  def upload_build(bot, upload_bucket, branch_name)
    s3_bucket = @s3.buckets[upload_bucket]
    if ( ! s3_bucket.exists?)
      puts "S3 bucket \"#{upload_bucket}\" does not exist."
      return
    end

    if (s3_bucket.objects["#{file_name}.plist"].exists?)
      return # Build already uploaded
    end

    ipa_file_name = "/Library/Server/Xcode/Data/BotRuns/BotRun-#{bot.latestSuccessfulBotRunGUID}.bundle/output/#{bot.long_name}.ipa"
    if ( ! File.exists?(ipa_file_name))
      puts "File not uploaded. \"#{ipa_file_name}\" does not exist."
      return
    end

    git_url = BotConfig.instance.github_url
    git_repo_name = git_url.sub('.git', '').split('/')[1]
    git_local_path = "/tmp/gitbot/#{git_repo_name}"
    if (File.directory?(git_local_path))
      git = Git.open(git_local_path, :log => Logger.new(STDOUT))
      puts "opening repo #{git_repo_name}."
    else
      git = Git.clone("/tmp/gitbot", git_repo, :path => git_local_path)
      puts "cloning repo #{git_repo_name}."
    end
    git.branch(branch_name)

    puts "git url #{git_url}"
    last_commit_hash = bot.commits[git_url]
    puts "Checking out commit #{last_commit_hash}"
    git.checkout(last_commit_hash)

    extract_location = File.join('/', 'tmp', "#{Time.now.getutc.to_s}", 'Info.plist')
    ZipFile.open(ipa_file_name) do |zf|
      zf.each do |e|
        if (e.name == "Info.plist")
          zf.extract(e.name, extract_location)
          break
        end
      end
    end

    if ( ! File.exists?(extract_location))
      puts "Could not extract Info.plist from ipa."
      return
    end

    plist_buddy_path = File.join('/', 'usr', 'libexec', 'PlistBuddy')
    version_string = %x(#{plist_buddy_path} -c "Print CFBundleVersion" #{extract_location})
    bundle_identifier = %x(#{plist_buddy_path} -c "Print CFBundleIdentifier" #{extract_location})
    bundle_display_name = %x(#{plist_buddy_path} -c "Print CFBundleDisplayName" #{extract_location})

    upload_display_name = BotConfig.instance.aws_upload_display_name(branch_name)
    title = (upload_display_name ? upload_display_name : bundle_display_name)

    key_prefix = "#{bundle_identifier}-#{version_string}"

    puts "Uploading #{title}..."

    # Upload ipa
    file_name = title.sub(' ', '-')
    s3_bucket.objects["#{file_name}.ipa"].write(:file => ipa_file_name, :acl => :public_read)
    puts "Uploaded ipa for \"#{title}\" on branch \"#{branch_name}\" to bucket #{upload_bucket}."

    # Upload plist
    template_path = File.join(File.dirname(__FILE__), '..', 'templates')
    plist_template = IO.read(File.join(template_path, 'plist.template'))
    template = Liquid::Template.parse(plist_template)
    ipa_url = "https://#{upload_bucket}.s3.amazonaws.com/#{file_name}.ipa"
    plist_string = template.render(
      'ipa_url' => ipa_url,
      'bundle_identifier' => bundle_identifier,
      'version_string' => version_string,
      'title' => title
      )
    s3_bucket.objects["#{file_name}.plist"].write(plist_string, :acl => :public_read)
    puts "Uploaded plist for \"#{title}\" on branch \"#{branch_name}\" to bucket #{upload_bucket}."

    # Upload html file
    builds = []
    custom_file_name = BotConfig.instance.aws_upload_html_file_name(branch_name)
    file_name = (custom_file_name ? custom_file_name : key_prefix)
    list_versions = BotConfig.instance.aws_upload_list_all_versions(branch_name)

    if (list_versions) # List each plist found in the bucket
      s3_bucket.objects.each do |object|
        if (object.key.end_with?('plist'))
          url = "https://#{upload_bucket}.s3.amazonaws.com/#{object.key}"
          build = {'url' => url, 'title' => object.key.sub('.plist', '')}
          builds << build
        end
      end
    else # Only list the plist that was just uploaded
      build = {'url' => ipa_url, 'title' => title}
      builds << build
    end
    html_template = IO.read("#{template_path}/html.template")
    template = Liquid::Template.parse(html_template)
    company_name = BotConfig.instance.company_name
    html_string = template.render('company_name' => company_name, 'builds' => builds)
    html_name = BotConfig.instance.aws_upload_file_name(branch_name)
    html_file_name = (html_name ? html_name : "index")
    s3_bucket.objects["#{html_file_name}.html"].write(html_string, :acl => :public_read)
    puts "Uploaded #{html_file_name}.html on branch \"#{branch_name}\" to bucket #{upload_bucket}."
  end
end
