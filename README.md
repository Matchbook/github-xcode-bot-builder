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
Make sure your Xcode server is correctly setup to allow ANYONE to create a build (without a username or password, see suggested features below).
Then make sure you can manually create and execute a build and run it.

Copy bot-sync-github.cfg.sample to ~/.bot-sync-github.cfg
See bot-sync-github.cfg.sample for a sample config.

Go to your [Github Account Settings](https://github.com/settings/applications) and create a personal access token which
you will use as your *github_access_token* so that the **bot-sync-github** script can access your github repo.

Go to your [AWS IAM Console](https://console.aws.amazon.com/iam/home?#users), [create a user](http://docs.aws.amazon.com/AWSSdkDocsRuby/latest/DeveloperGuide/ruby-dg-setup.html) with "s3:ListBucket", "s3:PutObject" and "s3:PutObjectAcl" permissions and generate an access key for the AWS API which will allow uploading builds to S3.

If running bot-sync-github on a Mac, create a Launch Agent file called "\<Company identifier in revers DNS notation\>.gitbot.plist" in ~/Library/LaunchAgents with the following contents:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string><company identifier in revers DNS notation>.gitbot</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/bot-sync-github</string>
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


