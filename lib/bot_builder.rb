require 'net/http'
require 'uri'
require 'cgi/cookie'
require 'SecureRandom'
require 'json'
require 'pp'
require 'bot_config'
require 'singleton'
require 'ostruct'

class BotBuilder
  include Singleton

  def delete_bot(guid)
    success = false
    service_requests = [ service_request('deleteBotWithGUID:', [guid]) ]
    delete_info = batch_service_request(service_requests)
    if (delete_info['responses'][0]['responseStatus'] == 'succeeded')
      puts "BOT Deleted #{guid}"
      success = true
    else
      puts "Error deleting BOT #{guid}"
    end
  end

  def create_bot(short_name, long_name, branch, scm_url, project_path, scheme_name, devices = [])
    device_guids = find_guids_for_devices(devices)
    if (device_guids.count != devices.count)
      puts "Some of the following devices could not be found on the server: #{devices}"
      exit 1
    end

    scm_guid = find_guid_for_scm_url(scm_url)
    if (scm_guid.nil? || scm_guid.empty?)
      puts "Could not find repository on the server #{scm_url}"
      exit 1
    end

    # Create the bot
    buildSchemeKey = (project_path =~ /xcworkspace/) ? :buildWorkspacePath : :buildProjectPath

    service_requests = [
        service_request('createBotWithProperties:', [
            {
                shortName: short_name,
                longName: long_name,
                extendedAttributes: {
                    scmInfo: {
                        "/" => {
                            scmBranch: branch,
                        }
                    },
                    scmInfoGUIDMap: {
                        "/" => scm_guid
                    },
                    buildSchemeKey => project_path,
                    buildSchemeName: scheme_name,
                    pollForSCMChanges: false,
                    buildOnTrigger: false,
                    buildFromClean: true,
                    integratePerformsAnalyze: true,
                    integratePerformsTest: true,
                    integratePerformsArchive: true,
                    deviceSpecification: "specificDevices",
                    deviceInfo: device_guids
                },
                notifyCommitterOnSuccess: false,
                notifyCommitterOnFailure: false,
                type: "com.apple.entity.Bot"
            }
        ])
    ]
    bot_info = batch_service_request(service_requests)
    bot_guid = bot_info['responses'][0]['response']['guid']
    puts "BOT Created #{bot_guid} #{short_name}"

    # Start the bot
    start_bot bot_guid

    bot_guid
  end

  def start_bot(bot_guid)
    service_requests = [ service_request('startBotRunForBotGUID:', [bot_guid]) ]
    bot_start_info = batch_service_request(service_requests)
    puts "BOT Started #{bot_guid}"
  end

  def status_of_all_bots
    # After immediately creating: latest_run_status "" run_sub_status ""
    # While running: latest_run_status "running" run_sub_status ""
    # After completion: latest_run_status "completed" run_sub_status "build-failed|build-errors|test-failures|warnings|analysis-issues|succeeded"
    service_requests = [ service_request('query:', [
        {
            fields: [
              'guid',
              'tinyID',
              'latestRunStatus',
              'latestRunSubStatus',
              'longName',
              'latestSuccessfulBotRunGUID',
              'latestRunSCMCommits'],
            entityTypes: ["com.apple.entity.Bot"]
        }
    ], 'SearchService') ]
    status_info = batch_service_request(service_requests)
    results =  status_info['responses'][0]['response']['results']
    statuses = {}
    results.each do |result|
      bot = OpenStruct.new result['entity']
      bot.status_url = "http://#{BotConfig.instance.xcode_server_hostname}/xcode/bots/#{bot.tinyID}"
      bot.latest_run_status = (bot.latestRunStatus.nil? || bot.latestRunStatus.empty?) ? :unknown : bot.latestRunStatus.to_sym
      bot.latest_run_sub_status = (bot.latestRunSubStatus.nil? || bot.latestRunSubStatus.empty?) ? :unknown : bot.latestRunSubStatus.to_sym
      bot.short_name = bot.tinyID
      bot.long_name = bot.longName
      bot.commits = latestRunSCMCommits
      bot.short_name_without_version = bot.short_name.sub(/_v\d*$/, '_v')
      statuses[bot.short_name_without_version] = bot
    end
    statuses
  end

  def status(arg0)
    status_of_all_bots.values.each do |bot|
      if ('guidonly' == arg0) #This is handy to list all GUIDs in a clean list for batch deleting
        puts "#{bot.guid}"
      else
        puts "#{bot.guid} #{bot.short_name} #{bot.latest_run_status} #{bot.latest_run_sub_status}"
      end
    end
  end

  def devices
    device_info = get_device_info
    device_info.each do |device|
      puts device_string_for_device(device)
    end
  end

  private

  def find_guid_for_scm_url(scm_url)
    scm_info = get_scm_info
    scm_guid = nil
    scm_info.each do |scm|
      if (scm['scmRepoPath'] == scm_url)
        scm_guid = scm['scmGUID']
      end
    end
    scm_guid
  end

  def find_guids_for_devices(devices)
    device_info = get_device_info
    device_guids = []
    device_info.each do |device|
      device_string = device_string_for_device device
      if (devices.include? device_string)
        device_guids << device['guid']
      end
    end
    device_guids
  end

  def device_string_for_device(device)
    "#{device['adcDevicePlatform']} #{device['adcDeviceName']} #{device['adcDeviceSoftwareVersion']}"
  end

  def get_device_info
    # Put to get device and Device Info
    service_requests = [
        service_request('allDevices', [])
    ]
    device_info = batch_service_request(service_requests)['responses'][0]['response']
    device_info
  end

  def get_scm_info
    # Put to get device and Device Info
    service_requests = [
        service_request('findAllSCMInfos', [])
    ]
    scm_info = batch_service_request(service_requests)['responses'][0]['response']
    scm_info
  end

  def get_session_guid
    # Get the guid
    if (@session_guid == nil)
      response = Net::HTTP.get_response(URI.parse("http://#{BotConfig.instance.xcode_server_hostname}/xcode"))
      cookies = CGI::Cookie::parse(response['set-cookie'])
      @session_guid = cookies['cc.collabd_session_guid']
    end
    @session_guid
  end

  def batch_service_request(service_requests)
    payload = {
        type: 'com.apple.BatchServiceRequest' ,
        requests: service_requests
    }
    http = Net::HTTP.new(BotConfig.instance.xcode_server_hostname)
    request = Net::HTTP::Put.new('/collabdproxy')
    request['Content-Type'] = 'application/json; charset=UTF-8'
    request['Cookie'] = "cc.collabd_session_guid=#{@session_guid}"
    request.body = payload.to_json
    response = http.request(request)
    json = JSON.parse(response.body)
    response_status = json['responses'][0]['responseStatus']
    json
  end

  def service_request(name, arguments, service = 'XCBotService')
    get_session_guid
    {
        type: 'com.apple.ServiceRequest',
        arguments: arguments,
        sessionGUID: @session_guid,
        serviceName: service,
        methodName: name,
        expandReferencedObjects: false
    }
  end

end