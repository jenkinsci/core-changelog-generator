Changelog generator for Jenkins Core
====================

[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/core-changelog-generator)](https://hub.docker.com/repository/docker/jenkins/core-changelog-generator)

The tools in this repo help with the creation of Jenkins core changelog drafts ([weekly](https://jenkins.io/changelog/), [LTS](https://jenkins.io/changelog-stable/)).
The Jenkins changelog is maintained in [the jenkins-infra/jenkins.io repository](https://github.com/jenkins-infra/jenkins.io/tree/master/content/_data/changelogs), and the generated pull requests should be submitted there.

# generate-jenkins-changelog

This tool can be used to generate a first draft of a Jenkins release's changelog.

## Usage in CLI

```
cd /path/to/clone/of/jenkinsci/jenkins.git
export GITHUB_AUTH=github_username:github_token

/path/to/generate-jenkins-changelog.rb <VERSION>
/path/to/generate-jenkins-changelog.rb <COMMIT>..<COMMIT>
```

## Usage in Docker

There is also a Dockerized version available:

* To reuse the Jenkins source code, pass the `/github/workspace` volume, e.g. `-v $(pwd)/test/jenkins:/github/workspace`.
  In such case there will be also a `changelog.yaml` file generated in the root of the repo
* If there is no arguments passed, the script will generate changelog since the last tag on the current branch

Generating changelog for pending changes:

```sh
export GITHUB_AUTH=github_username:github_token
docker run -e GITHUB_AUTH=${GITHUB_AUTH} -v $(pwd):/github/workspace --rm jenkins/core-changelog-generator
```

Generating changelog for a release:

```sh
export GITHUB_AUTH=github_username:github_token
docker run -e GITHUB_AUTH=${GITHUB_AUTH} -v $(pwd):/github/workspace --rm jenkins/core-changelog-generator 2.204
```

# lts-backports-changelog

This tool can be used to generate an LTS changelog for all the backported issues (labeled `2.xyz.w-fixed` in Jira) with corresponding changelog entries in the weekly changelog YAML file.
Weekly changelog YAML is optional, it will be downloaded from the [jenkins.io repository](https://github.com/jenkins-infra/jenkins.io/blob/master/content/_data/changelogs/weekly.yml) if not specified.

## Usage in CLI

```
export JIRA_AUTH=jira_username:jira_password

/path/to/lts-backports-changelog.rb <VERSION> <PATH/TO/weekly.yml>
```

## Usage in Docker

* To generate an LTS backports changelog, pass the `-e CHANGELOG_TYPE=lts` variable
* All options for `generate-jenkins-changelog` also apply here

Example:

```sh
docker run -e GITHUB_AUTH=${GITHUB_AUTH} -e JIRA_AUTH=${JIRA_AUTH} -e CHANGELOG_TYPE=lts -v $(pwd):/github/workspace --rm jenkins/core-changelog-generator 2.109.2
```
