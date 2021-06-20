#!/usr/bin/env ruby

require 'date'
require 'yaml'
require 'json'

git_repo = Dir.pwd

issues = []
hidden = []

curl_auth = ENV['GITHUB_AUTH']

if Dir.glob("licenseCompleter.groovy").empty?
	STDERR.puts "Usage:    generate-jenkins-changelog.rb <versions>"
	STDERR.puts ""
	STDERR.puts "This script needs to be run from a jenkinsci/jenkins clone."
	exit
end

if ARGV.length == 0
	STDERR.puts "Usage:    generate-jenkins-changelog.rb <versions>"
	STDERR.puts ""
	STDERR.puts "Missing argument <versions>"
	STDERR.puts "To generate the changelog between two commits or tags, specify then with '..' separator:"
	STDERR.puts "          generate-jenkins-changelog.rb jenkins-2.174..master"
	STDERR.puts "To generate the changelog for an existing Jenkins release (i.e. from the previous release), specify the version number:"
	STDERR.puts "          generate-jenkins-changelog.rb 2.174"
	exit
end

config_path=ENV['CONFIG_PATH']
STDERR.puts "Reading changelog configuration from #{config_path}"
config = YAML.load(File.read(config_path))
all_authors = []

if ARGV[0] =~ /\.\./
	# this is a commit range
	new_version = ARGV[0].split('..')[1]
	previous_version = ARGV[0].split('..')[0]
else
	new_version = "jenkins-#{ARGV[0]}"
	splitted = new_version.rpartition('.')
	previous_version = "#{splitted.first}.#{splitted.last.to_i - 1}"
end

STDERR.puts "Checking range from #{previous_version} to #{new_version}"

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
		STDERR.puts "PR #{pr[1]} found for #{sha}"

		pr_comment_string = `curl --fail --silent -u #{curl_auth} https://api.github.com/repos/jenkinsci/jenkins/pulls/#{pr[1]}`
		pr_commits_string = `curl --fail --silent -u #{curl_auth} https://api.github.com/repos/jenkinsci/jenkins/pulls/#{pr[1]}/commits`
		
		if $?.exitstatus  == 0

			pr_json = JSON.parse(pr_comment_string)
			commits_json = JSON.parse(pr_commits_string)

			labels = pr_json['labels'].map { |l| l["name"] }

			#TODO(oleg_nenashev): Extend release drafter format to fetch types from there?
			#TODO(oleg_nenashev): Some code refactorig would be cool to avoid such manual checks and ordering
			# Type for changelog rendering. Higher priorities are in the bottom
			entry['type'] = 'TODO'
			entry['type'] = 'rfe' if labels.include?("localization")
			entry['type'] = 'rfe' if labels.include?("developer")
			entry['type'] = 'rfe' if labels.include?("internal")
			entry['type'] = 'bug' if labels.include?("bug")
			entry['type'] = 'bug' if labels.include?("regression-fix")
			entry['type'] = 'rfe' if labels.include?("rfe")
			entry['type'] = 'major bug' if labels.include?("major-bug")
			entry['type'] = 'major rfe' if labels.include?("major-rfe")

			# Fetch categories by labels
			config['categories'].each do | category |
				if category['label'] != nil
					entry['category'] = category['title'] if labels.include?(category['label'])
				end
				if category['labels'] != nil
					if !(labels & category['labels']).empty?
						entry['category'] = category['title'] 
					end
				end
			end
			if entry['category'] == nil
				entry['category'] = 'TODO'
			end

			entry['pull'] = pr[1].to_i
			if issue != nil
				entry['issue'] = issue[1].to_i
			end

			# Resolve Authors
			# TODO(oleg_nenashev): GitHub REST API returns coauthors only as a part of the commit message string
			# "message": "Update core/src/main/java/hudson/model/HealthReport.java\n\nCo-Authored-By: Zbynek Konecny <zbynek1729@gmail.com>"
			# Ther is no REST API AFAICT, user => GitHub ID conversion also requires additional calls
			authors = []
			unresolvedAuthorEmails = []
			unresolvedAuthorNames = Hash.new
			commits_json.each do | commit |
				if commit["author"] # GitHub committer info is attached
					authors << commit["author"]["login"]
				else
					author = commit["commit"]["author"]
					unresolvedAuthorEmails << author["email"]
					unresolvedAuthorNames[author["email"]] = author["name"]
				end
			end
			
			#NOTE(oleg_nenashev): This code will be also needed for parsing co-authors
			unresolvedAuthorEmails.uniq.each do | email | # Try resolving users by asking GitHub
				STDERR.puts "Resolving GitHub ID for #{unresolvedAuthorNames[email]} (#{email})"
				usersearch_string = `curl --fail --silent -u #{curl_auth} https://api.github.com/search/users?q=#{email}%20in:email`
				usersearch = JSON.parse(usersearch_string)
				if usersearch["items"].length() > 0 
					githubId = usersearch["items"].first["login"]
					authors << githubId
				else
					authors << "TODO: #{unresolvedAuthorNames[email]} (#{email})"
				end
			end

			entry['authors'] = authors.uniq
			all_authors += entry['authors']

			proposed_changelog = /### Proposed changelog entries(.*?)(###|\Z)/m.match(pr_json['body'])
			if proposed_changelog != nil
				proposed_changelog = proposed_changelog[1]
				    .gsub("\r\n", "\n")
				    .gsub(/<!--.*?-->/m, "")
				    .gsub(/`(.+?)`/, '<code>\1</code>')
				    .gsub("\*", "").strip
			end

			# The presence of '\n' in this string is significant:
			# It's one of the ways the Psych YAML library uses to determine what format to print a string in.
			# This one makes it print a string literal (starting with |), which is easier to edit.
			# https://github.com/ruby/psych/blob/e01839af57df559b26f74e906062be6c692c89c8/lib/psych/visitors/yaml_tree.rb#L299
			if proposed_changelog == nil || proposed_changelog.empty?
				proposed_changelog = "(No proposed changelog)"
			end

			entry['pr_title'] = pr_json['title']
			if labels.include?("skip-changelog")
				entry['message'] = "PR title: #{pr_json['title']}"
				hidden << entry
			else
				prefix=""
				suffix=""
				prefix="Developer: " if labels.include?("developer")
				prefix="Internal:\n" if labels.include?("internal")
				suffix="\n(regression in TODO)" if labels.include?("regression-fix")
				entry['message'] = "#{prefix}TODO fixup changelog\n#{proposed_changelog.strip}#{suffix}"
				issues << entry
			end
		else
			STDERR.puts "Failed to retrieve PR metadata for <<<<<#{pr[1]}>>>>>"
		end
	else
		STDERR.puts "No PR found for #{sha}: <<<<<#{full_message.lines.first.strip}>>>>>"
	end
end

issues_by_category = issues.group_by { |issue| issue['category'] }
all_authors = all_authors.uniq

# Prepare ordered category list
categories = []
config['categories'].each do | category |
	categories << category['title']
end

def writeYAML(issues_by_category, categories, hidden, new_version)
	issues = []
	categories.each do |category|
		if issues_by_category.has_key?(category)
			issues << issues_by_category[category]
		end
	end
	issues = issues.flatten

	root = {}
	root['version'] = new_version.sub(/jenkins-/, '')
	root['date'] = Date.parse(`git log --pretty='%ad' --date=short #{new_version}^..#{new_version}`.strip)
	root['changes'] = issues

	changelog_yaml = [root].to_yaml.lines[1..-1].join
	hidden.sort { |a, b| a['pull'] <=> b['pull'] }.each do | entry |
		changelog_yaml += "\n  # pull: #{entry['pull']} (#{entry['message']})"
	end
	puts changelog_yaml

	changelog_path = ENV["CHANGELOG_YAML_PATH"]
	if changelog_path != nil
		STDERR.puts "Writing changelog to #{changelog_path}"
		File.write(changelog_path, changelog_yaml)
	end
end

def writeMarkdown(config, issues_by_category, categories, hidden, all_authors)
	changelog_path = ENV["CHANGELOG_MD_PATH"]
	if changelog_path == nil
		STDERR.puts "Will not write Markdown changelog, destination is undefined"
		return
	end
	
	changelog = ""
	
	changelog << "**Disclaimer**: This is an automatically generated changelog draft for Jenkins weekly releases.\n" 
	changelog << "See https://jenkins.io/changelog/ for the official changelogs.\n"
	changelog << "For `changelog.yaml` drafts see GitHub action artifacts attached to release commits.\n"

	categories.each do |category|
		if issues_by_category.has_key?(category)
			changelog << "\n## #{category}\n\n"
			issues_by_category[category].each do |issue|
				entry = issue['pr_title']
				authors = issue['authors'] != nil ? issue['authors'].map{ |author| "@#{author}" }.join(' ') : ""
				changelog_entry = "* #{entry} (##{issue['pull']}) #{authors}\n"

				# Apply replacers
				if config['replacers'] != nil
					config['replacers'].each do |replacer|
						if replacer['search'].start_with?("/")
							# TODO: Only globals are supported at the moment
							regex = replacer['search'].gsub(/\/(.*)\/g/,'\1')
							replace_by = replacer['replace'].gsub("$", "\\")
							STDERR.puts "replace #{regex} to #{replace_by}"
							changelog_entry = changelog_entry.gsub(/#{regex}/, replace_by)
						else
							changelog_entry = changelog_entry.gsub(replacer['search'], replacer['replace'])
						end
					end
				end
				changelog << changelog_entry
			end
		end
	end

	all_authors = all_authors != nil ? all_authors.map{ |author| "@#{author}" }.join(' ') : ""
	changelog << "\nAll contributors: #{all_authors}\n"

  puts changelog
	STDERR.puts "Writing changelog to #{changelog_path}"
	File.write(changelog_path, changelog)
end

writeYAML(issues_by_category, categories, hidden, new_version)
writeMarkdown(config, issues_by_category, categories, hidden, all_authors)
