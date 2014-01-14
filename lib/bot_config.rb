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

  def company_name(br)
    @config[:server][:company_name]
  end

  def test_on_pull_request(br)
    (!!@config[:server][:test_on_pull_request] ? true : false)
  end

  def test_on_branch_creation(br)
    (!!@config[:server][:test_on_branch_creation] ? true : false)
  end

  def xcode_devices(br)
    branch_parameter(br, :xcode_devices)
  end

  def xcode_scheme(br)
    branch_parameter(br, :xcode_scheme)
  end

  def aws_access_key_id(br)
    branch_parameter(br, :aws_access_key_id)
  end

  def aws_access_secret_key(br)
    branch_parameter(br, :aws_access_secret_key)
  end

  def aws_upload_bucket(br)
    branch_parameter(br, :aws_upload_bucket)
  end

  def aws_upload_name(br)
    branch_parameter(br, :aws_upload_name)
  end

  def bundle_identifier(br)
    branch_parameter(br, :bundle_identifier)
  end

  def aws_upload_html_name(br)
    branch_parameter(br, :aws_upload_html_name)
  end

  def aws_upload_list_all_versions(br)
    (!!branch_parameter(br, :aws_upload_list_all_versions) ? true : false)
  end

private

  def branch_parameter(br, key)
    if (@config[:branches](br.intern)
      @config[:branches][br.intern][key]
    else
      nil
    end
  end
end
