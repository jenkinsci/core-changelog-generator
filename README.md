# Jenkins Changelog Generator

The Jenkins changelog is maintained in [the jenkins-infra/jenkins.io repository](https://github.com/jenkins-infra/jenkins.io/tree/master/content/_data/changelogs).

This tool can be used to generate a first draft of a Jenkins release's changelog.

## Usage

```
cd /path/to/clone/of/jenkinsci/jenkins.git
export CURL_AUTH=github_username:github_token
/path/to/generate-jenkins-changelog.rb <VERSION>
```
