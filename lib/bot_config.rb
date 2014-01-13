require 'singleton'
require 'parseconfig'

class BotConfig
  include Singleton

  def initialize
    filename = File.expand_path('~/.bot-sync-github.cfg')
    if (!File.exists?(filename))
      $stderr.puts "Missing configuration file #{@filename}"
      exit 1
    end

    @config = ParseConfig.new(filename)
    @aws_upload_dict = eval(@config['aws_upload_dict'])

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
      #:aws_upload_dict
      #:company_name
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
    (!!:test_on_pull_request ? !!:test_on_pull_request : true)
  end

  def test_on_branch_creation
    (!!:test_on_branch_creation ? !!:test_on_branch_creation : false)
  end

  # nil values are allowed to be returned below
  def aws_access_key_id
    @config['aws_access_key_id']
  end

  def aws_access_secret_key
    @config['aws_access_secret_key']
  end

  def aws_upload_bucket(br)
    @aws_upload_dict[br]['branch']
  end

  def aws_upload_name(br)
    @aws_upload_dict[br]['name']
  end

  def aws_upload_bundle_identifier(br)
    @aws_upload_dict[br]['bundle_identifier']
  end

  def aws_upload_html_name(br)
    @aws_upload_dict[br]['html_name']
  end

  def aws_upload_list_versions(br)
    @aws_upload_dict[br]['list_versions']
  end

  def company_name
    @config['company_name']
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