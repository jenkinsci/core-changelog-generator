#!/usr/bin/env ruby

require 'yaml'

git_repo = Dir.pwd

issues = []

curl_auth = ENV['JIRA_AUTH']

if ARGV.length != 2
	puts "Usage:    generate-lts-changelog.rb <LTS version> <weekly.yml>"
	puts ""
	puts "Missing argument <version> and/or <weekly.yml>"
	puts "To generate the changelog for an LTS release:"
	puts "          generate-lts-changelog.rb 2.164.3 /path/to/jenkins.io/content/_data/changelogs/weekly.yml"
	exit
end

lts = ARGV[0]


weekly_changelog_file = ARGV[1]

backports_str = `set -o pipefail ; curl --fail -u #{curl_auth} -X POST --data '{"startAt":0, "maxResults":1000,"fields": ["key"], "jql": "labels = #{lts}-fixed" }' -H "Content-Type: application/json" https://issues.jenkins-ci.org/rest/api/2/search | jq -r '.issues[] | .key'`

backports = backports_str.lines.collect { |x| x.chomp }

changelog = YAML.load_file(weekly_changelog_file)

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

puts backported_issues.to_yaml
