require 'singleton'
require 'aws-sdk'
require 'bot_config'
require 'liquid'
require 'git'
require 'zip'
require 'fileutils'

class BotAWS
  include Singleton

  def initialize
    aws_access_key_id = BotConfig.instance.aws_access_key_id
    aws_access_secret_key = BotConfig.instance.aws_access_secret_key
    if ( ! aws_access_key_id || ! aws_access_secret_key)
      puts "Amazon access keys missing"
      return
    end

    AWS.config({
      :access_key_id => aws_access_key_id,
      :secret_access_key => aws_access_secret_key
    })
    @s3 = AWS::S3.new
  end

  def upload_build(bot, upload_bucket, branch_name)
    # Get S3 bucket instance and check for its existance
    s3_bucket = @s3.buckets[upload_bucket]
    if ( ! s3_bucket.exists?)
      puts "S3 bucket \"#{upload_bucket}\" does not exist"
      return
    end

    # Build path to .ipa and check for its existance
    ipa_file_name = File.join(
      '/',
      'Library',
      'Server',
      'Xcode',
      'Data',
      'BotRuns',
      "BotRun-#{bot.latestSuccessfulBotRunGUID}.bundle",
      'output',
      "#{bot.long_name}.ipa"
      )
    if ( ! File.exists?(ipa_file_name))
      puts "File not uploaded. \"#{ipa_file_name}\" does not exist"
      return
    end

    # Extract Info.plist from .ipa
    extract_location = File.join('/', 'tmp', 'gitbot', Time.now.to_i.to_s)
    info_plist_location = File.join(extract_location, 'Info.plist')
    Zip::File.open(ipa_file_name) do |zf|
      zf.each do |e|
        if (e.name.end_with?('Info.plist'))
          FileUtils.mkdir_p(extract_location)
          zf.extract(e, info_plist_location)
          break
        end
      end
    end

    # Check if Info.plist was extracted successfully
    if ( ! File.exists?(info_plist_location))
      puts "Could not extract Info.plist from ipa"
      return
    end

    # Get build info from Info.plist extracted above
    plist_buddy_path = File.join('/', 'usr', 'libexec', 'PlistBuddy')
    bundle_version_string = %x(#{plist_buddy_path} -c "Print CFBundleVersion" #{info_plist_location})
    bundle_version_string_exit = $?.to_i
    bundle_identifier = %x(#{plist_buddy_path} -c "Print CFBundleIdentifier" #{info_plist_location})
    bundle_identifier_exit = $?.to_i
    bundle_display_name = %x(#{plist_buddy_path} -c "Print CFBundleDisplayName" #{info_plist_location})
    bundle_display_name_exit = $?.to_i

    # Clean up tmp Info.plist
    FileUtils.rm_r(extract_location)

    # Check if any of the above shell commands failed
    if (bundle_version_string_exit || bundle_identifier_exit || bundle_display_name_exit)
      puts "Unable to parse build info from Info.plist"
      return
    end

    upload_display_name = BotConfig.instance.aws_upload_display_name(branch_name)
    title = (upload_display_name ? upload_display_name : "#{bundle_display_name}-#{bundle_version_string}")

    file_name = "#{bundle_identifier}-#{bundle_version_string}"

    # Check for existance of .plist so build is only uploaded ince
    if (s3_bucket.objects["#{file_name}.plist"].exists?)
      return # Build already uploaded
    end

    puts "Uploading #{title}..."

    # Upload ipa
    s3_bucket.objects["#{file_name}.ipa"].write(:file => ipa_file_name, :acl => :public_read)
    puts "Uploaded ipa for \"#{title}\" on branch \"#{branch_name}\" to bucket #{upload_bucket}"

    # Create and upload plist
    template_path = File.join(File.dirname(__FILE__), '..', 'templates')
    plist_template = IO.read(File.join(template_path, 'plist.template'))
    template = Liquid::Template.parse(plist_template)
    ipa_url = "https://#{upload_bucket}.s3.amazonaws.com/#{file_name}.ipa"
    plist_string = template.render(
      'ipa_url' => ipa_url,
      'bundle_identifier' => bundle_identifier,
      'version_string' => bundle_version_string,
      'title' => title
      )
    s3_bucket.objects["#{file_name}.plist"].write(plist_string, :acl => :public_read)
    puts "Uploaded plist for \"#{title}\" on branch \"#{branch_name}\" to bucket #{upload_bucket}"

    # Create and upload html file
    builds = []
    custom_file_name = BotConfig.instance.aws_upload_html_file_name(branch_name)
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
    html_template = IO.read(File.join(template_path, 'html.template'))
    template = Liquid::Template.parse(html_template)
    company_name = BotConfig.instance.company_name
    html_string = template.render('company_name' => company_name, 'builds' => builds)
    html_name = BotConfig.instance.aws_upload_html_file_name(branch_name)
    html_file_name = (html_name ? html_name : "index")
    s3_bucket.objects["#{html_file_name}.html"].write(html_string, :acl => :public_read)
    puts "Uploaded #{html_file_name}.html on branch \"#{branch_name}\" to bucket #{upload_bucket}"

    # Clone or open repo so version can be bumped
    git_url = BotConfig.instance.github_url
    git_repo_name = git_url.sub('.git', '').split('/')[-1]
    temp_path = File.join('/', 'tmp', 'gitbot')
    git_local_path = File.join(temp_path, git_repo_name)
    if (File.directory?(git_local_path))
      puts "Opening repo #{git_repo_name}"
      git = Git.open(git_local_path, :log => Logger.new(STDOUT))
    else
      puts "Cloning repo #{git_repo_name}"
      # FileUtils.mkdir_p shouldn't be nessesary as directory is created when
      # extracting Info.plist, but here just in case the path for repos is changed.
      FileUtils.mkdir_p(temp_path)
      git = Git.clone(git_url, git_repo_name, :path => temp_path)
    end

    # Switch to the proper git branch and checkout commit for this build
    #git.branch(branch_name)
    git_branch = g.branch(branch_name)
    git.pull(git_branch)
    git.checkout(git_branch)
    last_commit_hash = Git::Log.last
    test_commit_hash = bot.commits[git_url]
    puts "Git test:\n#{last_commit_hash}\n#{test_commit_hash}"
    #puts "Checking out commit #{last_commit_hash}"
    #git.checkout(last_commit_hash)

    # Bump build version
    agvtool_path = File.join('/', 'usr', 'bin', 'agvtool')
    Dir.chdir(git_local_path)
    version = 100
    error = %x(#{agvtool_path} new-version #{version})
    if ($?.to_i)
      puts "Error bumping build version - #{error}"
      return
    end
    #g.commit_all("Bumped build version to #{version}.")
  end
end
