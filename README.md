This is a fork of the [original project](https://github.com/modcloth-labs/github-xcode-bot-builder) heavily modified to suite our needs. Bot creation on pull request is probably broken and lots of refactoring is needed. Significant changes includes:

1. Bot creation for new branches.

2. Uploading of builds to an AWS S3 bucket which allows easy distribution for QA or betas.

3. The config file changed to JSON format to allow more granular configuration for each branch.

Github Xcode Bot Builder
===============================
A command line tool that creates/manages/deletes Xcode 5 server bots for each Github pull request or branch creation.

If enabled, when a pull request is opened a corresponding Xcode bot is created. When a new commit is pushed the bot is re-run. When the build finishes the github pull request status is updated with a comment if there's an error. Users can request that a pull request be retested by adding a comment that includes the word "retest" (case insensitive). When a pull request is closed the corresponding bot is deleted.

If enabled, when a branch is created a corresponding Xcode bot is created. When a new commit is pushed the bot is re-run. When the build finishes the github commit status is updated. When a branch is deleted the corresponding bot is deleted.

Setup
====================================
Make sure your Xcode server is correctly setup to allow ANYONE to create a build (without a username or password, see suggested features below). Then make sure you can manually create and execute a build and run it.

Copy bot-sync-github.cfg.sample to ~/.bot-sync-github.cfg

bot-sync-github.cfg.sample has some notations explaining the options. Here are more detailed explainations:


*server section* - This section contains global configuration options.

*github_access_token* - Go to your [Github Account Settings](https://github.com/settings/applications) and create a personal access token which you will use as your *github_access_token* so that the **bot-sync-github** script can access your github repo.

*github_url* - The url to your github repo (i.e. git@github.com:\<user\>/\<repo\>).

*github_repo* - The user/repo name (\<user\>/\<repo\>) This may be removed in the future as it can derived from the github_url paramter above.

*aws_access_key_id (optional)* - Go to your [AWS IAM Console](https://console.aws.amazon.com/iam/home?#users), [create a user](http://docs.aws.amazon.com/AWSSdkDocsRuby/latest/DeveloperGuide/ruby-dg-setup.html) with "s3:ListBucket", "s3:PutObject" and "s3:PutObjectAcl" permissions and generate an access key for the AWS API.

*aws_access_secret_key (optional)* - Access key secret for credentials generated above.

*xcode_server_hostname* - The hostname of your xcode server. If bot-sync-github is on the same machine as your xcode server, this can be localhost. However, the Github web interface provides links to the xcode server web interface in pull requests statuses. In order for those links to work outside of the xcode server machine, put the external hostname or ip of xcode server here.

*company_name (optional)* - Only relevant for uploading builds to AWS S3. This name appears in the HTML \<title\> tag.

*xcode_project_or_workspace* - The name of your xcode project or workspace to be CI'd.

*test_on_pull_request (optional)* - If set to true, a new xocde bot will be created when a new pull request is opened, and will be re-run when a new commit is made on the pull request or when the word "retest" is posted as a comment on the pull request. The bot will be delete when the pull request is closed. This parameter defaults to false if not present.

*test_on_branch_creation (optional)* - If set to true, a new xcode bot will be created when a new branch is created, and will be re-run when a new commit is made on the branch. The bot will be deleted when the branch is deleted. This parameter defaults to false.

While the two options above are both optional, if neither is present (or set to false) then no bots will ever created.


*branches* - This section has configuration options for each branch. Within the "branches" section, the "default" section specifies configuration options for every branch unless a sub-section named after the branch is present.

*xcode_devices* - An array of devices which tests should be run on. At least one device is required.

*xcode_scheme* - The scheme to run tests on. A new xocde project contains one scheme named after the target. If the name of your project is "MyApp", the the scheme name will likely be "MyApp".

*pass_on_warnings (optional)* - If a project has warnings during build bot-sync-github noramlly fails it. Setting this to true will pass a build even if it has warnings. This parameter defaults to false if not present.

*pass_on_analyzer_issues (optional)* - If a project has analyzer issues during build bot-sync-github noramlly fails it. Setting this to true will pass a build even if it has analyzer issues. This parameter defaults to false if not present.

*aws_upload_bucket (optional)* - The name of the Amazon AWS S3 bucket in which to upload builds. If this parameter is missing (or null), builds will not be uploaded.

*aws_upload_html_file_name (optional)* - Builds uploaded to a Amazon AWS S3 bucket also has an accompanying HTML file which will display a link for the user will tap to initiate the download. This parameter is the name of the HTML file. By using different file names for each branch, the same S3 bucket can hosts builds for multiple branches. If this parameter is missing (or null), index.html is used.

*aws_upload_display_name (optional)* - This is the text of the link in the above mentioned HTML file the user will tap to download a build on their device. If missing (or null), the text in the ipa's Info.plist CFBundleDisplayName field is used.

*aws_upload_list_all_versions (optional)* - When generating the HTML file mentioned above, only the most recent build is listed in the HTML file. Setting this parameter to true will list all versions of the app uploaded to the S3 bucket. This parameter defaults to false if not present. Using this parameter when uploading multiple branches to the same bucket has unpredictable behavior and is not recommended until a fix can be made. 

*git_tag_prefix (optional)* - This parameter specifies the prefix for the git tag which is created after a build is uploaded to an Amazon AWS S3 bucket. As an example, with prefix of "beta" an app which has a major/minor/build of 1.0.1 will be tagged in git as "beta1.0.1". If missing (or null), no git tag will be created.


If running bot-sync-github on a Mac, create a Launch Agent file called "\<Company identifier in reverse DNS notation\>.gitbot.plist" in ~/Library/LaunchAgents with the following contents:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string><company identifier in reverse DNS notation>.gitbot</string>
    <key>ProgramArguments</key>
    <array>
        <string><path to bot-sync-github>(e.g. /usr/bin/bot-sync-github)</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
</dict>
</plist>
```

After creating file, type:
```
launchctl load ~/Library/LaunchAgents/<plist filename>
```
to run bot-sync-github every 60 seconds.

Other OSs will require a different method to run bot-sync-github (e.g. cron).

Troubleshooting
====================================
Send us a pull request with your troubleshooting tips here!

Contributing
====================================
* You may want to consider contributing to the [original project](https://github.com/modcloth-labs/github-xcode-bot-builder) as more people will probably benefit from changes there.
* Github Xcode Bot Builder uses [Jeweler](https://github.com/technicalpickles/jeweler) for managing the Gem, versioning, generating the Gemspec, etc. so do not manually edit the gemspec since it is auto generated from the Rakefile.
* Check out the latest **master** to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Don't forget to add yourself to the contributors section below

Suggested features to contribute
====================================
* Support for configuring username and password to use with your Xcode server
* Add specs that use VCR to help us add test coverage
* Add support for multiple repositories
* Add better error handling
* Validation of config file
* Update this README.md to make it easier for new users to get started and troubleshoot

Contributors
====================================
 - [ModCloth](http://www.modcloth.com/)
 - [Geoffery Nix](http://github.com/geoffnix)
 - [Two Bit Labs](http://twobitlabs.com/)
 - [Todd Huss](http://github.com/thuss)
 - [Tom Corwine](https://github.com/TomCorwine)

Copyright
====================================
Copyright (c) 2013 ModCloth. See LICENSE for further details.
