#!/usr/bin/env ruby

require 'yaml'
require 'json'

git_repo = Dir.pwd

issues = []

curl_auth = ENV['GITHUB_AUTH']

if Dir.glob("licenseCompleter.groovy").empty?
	puts "Usage:    generate-jenkins-changelog.rb <versions>"
	puts ""
	puts "This script needs to be run from a jenkinsci/jenkins clone."
	exit
end

if ARGV.length == 0
	puts "Usage:    generate-jenkins-changelog.rb <versions>"
	puts ""
	puts "Missing argument <versions>"
	puts "To generate the changelog between two commits or tags, specify then with '..' separator:"
	puts "          generate-jenkins-changelog.rb jenkins-2.174..master"
	puts "To generate the changelog for an existing Jenkins release (i.e. from the previous release), specify the version number:"
	puts "          generate-jenkins-changelog.rb 2.174"
	exit
end

if ARGV[0] =~ /\.\./
	# this is a commit range
	new_version = ARGV[0].split('..')[1]
	previous_version = ARGV[0].split('..')[0]
else
	new_version = "jenkins-#{ARGV[0]}"
	splitted = new_version.rpartition('.')
	previous_version = "#{splitted.first}.#{splitted.last.to_i - 1}"
end

puts "Checking range from #{previous_version} to #{new_version}"

# We generally want --first-parent here unless it's the weekly after a security update
# In that case, the merge commit after release will hide anything merged Monday through Wednesday
diff = `git log --pretty=oneline #{previous_version}..#{new_version}`

diff.each_line do |line|
	pr = /#([0-9]{4,5})[) ]/.match(line)
	sha = /^([0-9a-f]{40}) /.match(line)[1]
	full_message = `git log --pretty="%s%n%n%b" #{sha}^..#{sha}`
	issue = /JENKINS-([0-9]{3,5})/.match(full_message.encode("UTF-16be", :invalid=>:replace, :replace=>"?").encode('UTF-8'))
	entry = {}
	if pr != nil

		pr_comment_string = `curl --fail -u #{curl_auth} https://api.github.com/repos/jenkinsci/jenkins/pulls/#{pr[1]}`
		if $?.exitstatus  == 0

			pr_json = JSON.parse(pr_comment_string)

			entry['type'] = 'TODO'
			entry['pull'] = pr[1].to_i
			if issue != nil
				entry['issue'] = issue[1].to_i
			end

			proposed_changelog = /### Proposed changelog entries(.*?)(###|\Z)/m.match(pr_json['body'])
			if proposed_changelog != nil
				proposed_changelog = proposed_changelog[1].gsub("\r\n", "\n").gsub(/<!--.*?-->/m, "").strip
			end

			# The presence of '\n' in this string is significant:
			# It's one of the ways the Psych YAML library uses to determine what format to print a string in.
			# This one makes it print a string literal (starting with |), which is easier to edit.
			# https://github.com/ruby/psych/blob/e01839af57df559b26f74e906062be6c692c89c8/lib/psych/visitors/yaml_tree.rb#L299
			if proposed_changelog == nil || proposed_changelog.empty?
				proposed_changelog = "(No proposed changelog)"
			end

			entry['message'] = "TODO fixup changelog:\nPR title: #{pr_json['title']}\nProposed changelog:\n#{proposed_changelog.strip}"

			issues << entry
		else
			puts "Failed to retrieve PR metadata for <<<<<#{pr[1]}>>>>>"
		end
	else
		puts "No PR found for #{sha}: <<<<<#{full_message.lines.first.strip}>>>>>"
	end
end

root = {}
root['version'] = new_version
root['date'] = Date.parse(`git log --pretty='%ad' --date=short #{new_version}^..#{new_version}`.strip)
root['changes'] = issues

puts [root].to_yaml
