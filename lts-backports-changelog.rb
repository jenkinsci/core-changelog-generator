#!/usr/bin/env ruby

require 'yaml'
require "open-uri"
require 'shellwords'

git_repo = Dir.pwd

issues = []

curl_auth = ENV['JIRA_AUTH']

if ARGV.length < 1 || ARGV.length > 2
	puts "Usage:    generate-lts-changelog.rb <LTS version> [weekly.yml]"
	puts ""
	puts "Default weekly.yml: https://github.com/jenkins-infra/jenkins.io/blob/master/content/_data/changelogs/weekly.yml"
	puts ""
	puts "ERROR: Wrong argument number"
	puts "To generate the changelog for an LTS release:"
	puts "          generate-lts-changelog.rb 2.164.3 /path/to/jenkins.io/content/_data/changelogs/weekly.yml"
	puts ""
	exit
end

lts = ARGV[0]


weekly_changelog_file = ARGV[1]

command = "set -o pipefail ; curl --fail -u #{curl_auth} -X POST --data '{\"startAt\":0, \"maxResults\":1000,\"fields\": [\"key\"], \"jql\": \"labels = #{lts}-fixed\" }' -H \"Content-Type: application/json\" https://issues.jenkins-ci.org/rest/api/2/search | jq -r '.issues[] | .key'"
escaped_command = Shellwords.escape(command)
backports_str = `bash -c #{escaped_command}`

backports = backports_str.lines.collect { |x| x.chomp }

if weekly_changelog_file == nil
  puts "WARNING: Weekly changelog YAML is not specified. Using https://github.com/jenkins-infra/jenkins.io/blob/master/content/_data/changelogs/weekly.yml"
  weekly_changelog_file = "https://raw.githubusercontent.com/jenkins-infra/jenkins.io/master/content/_data/changelogs/weekly.yml"
end

if weekly_changelog_file =~ /https:\/\//
	yaml_content = open(weekly_changelog_file){|f| f.read}
	changelog = YAML::load(yaml_content)
else
	changelog = YAML.load_file(weekly_changelog_file)
end

backported_issues = []

changelog.each do |version|
	version["changes"].each do |change|
		issue = change["issue"]
		if issue != nil
			if backports.include?("JENKINS-#{issue}")
				backported_issues << change
			end
		else
			if change["references"]
				change["references"].each do |entry|
					if entry["issue"] && backports.include?("JENKINS-#{entry["issue"]}")
						backported_issues << change
					end
				end
			end
		end
	end
end

changelog_yaml = backported_issues.to_yaml
puts changelog_yaml

changelog_path = ENV["CHANGELOG_YAML_PATH"]
if changelog_path != nil
	puts "Writing changelog to #{changelog_path}"
	File.write(changelog_path, changelog_yaml)
end
