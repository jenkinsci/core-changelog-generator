#!/usr/bin/env ruby

if Dir.glob("*").empty?
    puts "Running in empty directory, '/src/jenkins' is not passed as volume. Will clone the repository"
    system("git config --global --add safe.directory %s" % [Dir.getwd])
    system("git clone https://github.com/jenkinsci/jenkins.git .")
    if $?.exitstatus  != 0
        puts "ERROR: Clone failed"
        exit  $?.exitstatus    
    end
end

args = ARGV
if args.empty?
    puts "No version/range passed, will generate changelog since the last commit"
    start_tag = `git describe --abbrev=0`.strip
    end_commit = `git rev-parse HEAD`.strip
    args = [ "%s..%s" % [start_tag,end_commit] ]
end

if ENV["CHANGELOG_TYPE"] == "lts"
    system("/jenkins-changelog-generator/bin/lts-backports-changelog", *args)
else
    system("/jenkins-changelog-generator/bin/generate-jenkins-changelog", *args)
end
