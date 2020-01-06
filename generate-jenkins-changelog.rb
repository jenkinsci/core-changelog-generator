#!/usr/bin/env ruby

require 'date'
require 'yaml'
require 'json'

git_repo = Dir.pwd

issues = []
hidden = []

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
		puts "PR #{pr[1]} found for #{sha}"

		pr_comment_string = `curl --fail --silent -u #{curl_auth} https://api.github.com/repos/jenkinsci/jenkins/pulls/#{pr[1]}`
		if $?.exitstatus  == 0

			pr_json = JSON.parse(pr_comment_string)

			labels = pr_json['labels'].map { |l| l["name"] }

			#TODO(oleg_nenashev): Some code refactorig would be cool to avoid such manual checks and ordering
			# Type for changelog rendering. Higher priorities are in the bottom
			entry['type'] = 'TODO'
			entry['type'] = 'rfe' if labels.include?("localization")
			entry['type'] = 'rfe' if labels.include?("developer")
			entry['type'] = 'rfe' if labels.include?("internal")
			entry['type'] = 'bug' if labels.include?("bug")
			entry['type'] = 'rfe' if labels.include?("rfe")
			entry['type'] = 'major bug' if labels.include?("major-bug")
			entry['type'] = 'major rfe' if labels.include?("major-rfe")
			entry['type'] = 'major bug' if labels.include?("regression-fix")

			# Category for changelog ordering. Higher priorities are in the bottom
			entry['category'] = 'TODO'
			entry['category'] = 'localization' if labels.include?("localization")
			entry['category'] = 'developer' if labels.include?("developer")
			entry['category'] = 'internal' if labels.include?("internal")
			entry['category'] = 'bug' if labels.include?("bug")
			entry['category'] = 'rfe' if labels.include?("rfe")
			entry['category'] = 'major bug' if labels.include?("major-bug")
			entry['category'] = 'major rfe' if labels.include?("major-rfe")
			entry['category'] = 'regression' if labels.include?("regression-fix")

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

			if labels.include?("skip-changelog")
				entry['message'] = "PR title: #{pr_json['title']}"
				hidden << entry
			else
				prefix=""
				suffix=""
				prefix="Developer:\n" if labels.include?("developer")
				prefix="Internal:\n" if labels.include?("internal")
				suffix="\n(regression in TODO)" if labels.include?("regression-fix")
				entry['message'] = "#{prefix}TODO fixup changelog:\nPR title: #{pr_json['title']}\nProposed changelog:\n#{proposed_changelog.strip}#{suffix}"
				issues << entry
			end
		else
			puts "Failed to retrieve PR metadata for <<<<<#{pr[1]}>>>>>"
		end
	else
		puts "No PR found for #{sha}: <<<<<#{full_message.lines.first.strip}>>>>>"
	end
end

issues_by_category = issues.group_by { |issue| issue['category'] }

issues = []
['regression', 'major rfe', 'major bug', 'rfe', 'bug', 'localization', 'developer', 'internal', 'TODO'].each do |category|
	if issues_by_category.has_key?(category)
		issues << issues_by_category[category]
	end
end
issues = issues.flatten

root = {}
root['version'] = new_version.sub(/jenkins-/, '')
root['date'] = Date.parse(`git log --pretty='%ad' --date=short #{new_version}^..#{new_version}`.strip)
root['changes'] = issues

changelog_yaml = [root].to_yaml
hidden.sort { |a, b| a['pull'] <=> b['pull'] }.each do | entry |
	changelog_yaml += "\n  # pull: #{entry['pull']} (#{entry['message']})"
end
puts changelog_yaml

changelog_path = ENV["CHANGELOG_YAML_PATH"]
if changelog_path != nil
	puts "Writing changelog to #{changelog_path}"
	File.write(changelog_path, changelog_yaml)
end
