#!/usr/bin/env ruby

require 'yaml'
require 'json'

git_repo = Dir.pwd

issues = []

curl_auth = ENV['CURL_AUTH']

new_version = ARGV[0]
previous_version = "#{new_version.split('.')[0]}.#{new_version.split('.')[1].to_i - 1}"

diff = `git log --pretty=oneline --first-parent jenkins-#{previous_version}..jenkins-#{new_version}`

diff.each_line do |line|
	pr = /#([0-9]{4,5})/.match(line)
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

			proposed_changelog = /### Proposed changelog entries(.*?)###/m.match(pr_json['body'])
			if proposed_changelog != nil
				proposed_changelog = proposed_changelog[1].gsub("\r\n", "\n").gsub(/<!--.*?-->/m, "").strip
			end

			# The presence of '\n' in this string is significant:
			# It's one of the ways the Psych YAML library uses to determine what format to print a string in.
			# This one makes it print a string literal (starting with |), which is easier to edit.
			# https://github.com/ruby/psych/blob/e01839af57df559b26f74e906062be6c692c89c8/lib/psych/visitors/yaml_tree.rb#L299
			if proposed_changelog == nil || proposed_changelog.empty?
				proposed_changelog = "No changelog for:\n#{pr_json['title']}"
			end

			entry['message'] = "TODO fixup changelog:\n#{proposed_changelog.strip}"

			issues << entry
		else
			puts "Failed to retrieve PR metadata for #{pr[1]}"
		end
	else
		puts "No PR found for #{sha}: #{full_message}"
	end
end

root = {}
root['version'] = new_version
root['date'] = Date.parse(`git log --pretty='%ad' --date=short jenkins-#{new_version}^..jenkins-#{new_version}`.strip)
root['changes'] = issues

puts [root].to_yaml
