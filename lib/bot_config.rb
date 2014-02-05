require 'singleton'
require 'json'

class BotConfig
  include Singleton

  def initialize
    filename = File.expand_path('~/.bot-sync-github.cfg')
    if (!File.exists?(filename))
      $stderr.puts "Missing configuration file #{@filename}"
      exit 1
    end

    @config = JSON.parse(IO.read(filename), :symbolize_names => true)
  end

  def xcode_server_hostname
    @config[:server][:xcode_server_hostname]
  end

  def github_access_token
    @config[:server][:github_access_token]
  end

  def github_url
    @config[:server][:github_url]
  end

  def github_repo
    @config[:server][:github_repo]
  end

  def xcode_project_or_workspace
    @config[:server][:xcode_project_or_workspace]
  end

  def company_name
    @config[:server][:company_name]
  end

  def aws_access_key_id
    @config[:server][:aws_access_key_id]
  end

  def aws_access_secret_key
    @config[:server][:aws_access_secret_key]
  end

  def test_on_pull_request
    (!!@config[:server][:test_on_pull_request] ? true : false)
  end

  def test_on_branch_creation
    (!!@config[:server][:test_on_branch_creation] ? true : false)
  end

  def xcode_devices(br)
    branch_parameter(br, :xcode_devices)
  end

  def xcode_scheme(br)
    branch_parameter(br, :xcode_scheme)
  end

  def pass_on_warnings(br)
    branch_parameter(br, :pass_on_warnings)
  end

  def pass_on_analyzer_issues(br)
    branch_parameter(br, :pass_on_analyzer_issues)
  end

  def aws_upload_bucket(br)
    branch_parameter(br, :aws_upload_bucket)
  end

  def aws_bucket_base_url(br)
    branch_parameter(br, :aws_bucket_base_url)
  end

  def aws_upload_display_name(br)
    branch_parameter(br, :aws_upload_display_name)
  end

  def aws_upload_plist_file_name(br)
    branch_parameter(br, :aws_upload_plist_file_name)
  end

  def aws_upload_html_file_name(br)
    branch_parameter(br, :aws_upload_html_file_name)
  end

  def aws_upload_list_all_versions(br)
    (!!branch_parameter(br, :aws_upload_list_all_versions) ? true : false)
  end

  def git_tag_prefix(br)
    branch_parameter(br, :git_tag_prefix)
  end

  def crittercism_app_id(br)
    branch_parameter(br, :crittercism_app_id)
  end

  def crittercism_api_key(br)
    branch_parameter(br, :crittercism_api_key)
  end

private

  def branch_parameter(br, key)
    if (@config[:branches].key?(br.intern)) && (@config[:branches][br.intern].key?(key))
      # There is a config for this branch and it contains this key
      return @config[:branches][br.intern][key]
    end

    # If key does not exist on the branch specific config, check the default config
    # This allows there to be an inheritance to the config - branch specific configs
    # inherite the values of the default config and can override them.

    if (@config[:branches].key?(:default)) # Check to insure default section exists
      @config[:branches][:default][key]
    else
      nil
    end
  end
end
