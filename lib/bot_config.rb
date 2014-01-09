require 'singleton'
require 'parseconfig'

class BotConfig
  include Singleton

  def initialize
    @filename = File.expand_path('~/.bot-sync-github.cfg')
    if (!File.exists? @filename)
      $stderr.puts "Missing configuration file #{@filename}"
      exit 1
    end

    @config = ParseConfig.new(@filename)

    # Make sure every param is configured properly since param will throw an error for a missing key
    [
      :xcode_server,
      :github_url,
      :github_repo,
      :github_access_token,
      :xcode_devices,
      :xcode_scheme,
      :xcode_project_or_workspace,
      # These parameters are optional
      #:test_on_pull_request,
      #:test_on_branch_creation,
      #:aws_access_key_id,
      #:aws_access_secret_key,
      #:aws_upload_bucket_dict
      ].each do |key|
      param key
    end
  end

  def xcode_server_hostname
    param :xcode_server
  end

  def github_access_token
    param :github_access_token
  end

  def scm_path
    param :github_url
  end

  def github_repo
    param :github_repo
  end

  def xcode_devices
    param(:xcode_devices).split('|')
  end

  def xcode_scheme
    param :xcode_scheme
  end

  def xcode_project_or_workspace
    param :xcode_project_or_workspace
  end

  def test_on_pull_request
    (:test_on_pull_request ? :test_on_pull_request : true)
  end

  def test_on_branch_creation
    (:test_on_branch_creation ? :test_on_branch_creation : false)
  end

  # nil values are allowed to be returned below
  def aws_access_key_id
    :aws_access_key_id
  end

  def aws_access_secret_key
    :aws_access_secret_key
  end

  def aws_upload_bucket(br)
    :aws_upload_bucket_dict[br]
  end

  def param(key)
    value = @config[key.to_s]
    if (value.nil?)
      $stderr.puts "Missing configuration key #{key} in #{@filename}"
      exit 1
    end
    value
  end

end