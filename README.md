The Jenkins changelog is maintained in [the jenkins-infra/jenkins.io repository](https://github.com/jenkins-infra/jenkins.io/tree/master/content/_data/changelogs).

The tools in this repo help with the creation of changelogs.

# generate-jenkins-changelog

This tool can be used to generate a first draft of a Jenkins release's changelog.


## Usage

```
cd /path/to/clone/of/jenkinsci/jenkins.git
export GITHUB_AUTH=github_username:github_token

/path/to/generate-jenkins-changelog.rb <VERSION>
/path/to/generate-jenkins-changelog.rb <COMMIT>..<COMMIT>
```

# lts-backports-changelog

This tool can be used to generate an LTS changelog for all the backported issues (labeled `2.xyz.w-fixed` in Jira) with corresponding changelog entries in the weekly changelog YAML file.


## Usage

```
export JIRA_AUTH=jira_username:jira_password

/path/to/lts-backports-changelog.rb <VERSION> <PATH/TO/weekly.yml>
```

# Usage in Docker

There is also a Dockerized version available:

* To reuse the Jenkins source code, pass the `/src/jenkins` volume, e.g. `-v $(pwd)/test/jenkins:/src/jenkins`.
  In such case there will be also a `changelog.yaml` file generated in the root of the repo
* To generate an LTS backports changelog, pass the `-e CHANGELOG_TYPE=lts` variable.
* If there is no arguments passed, the script will generate changelog since the last tag on the current branch

Generating changelog for pending changes:

```sh
export GITHUB_AUTH=github_username:github_token
docker run -e GITHUB_AUTH=${GITHUB_AUTH} -v $(pwd):/src/jenkins --rm onenashev/jenkins-changelog-generator
```

Generating changelog for a release:

```sh
export GITHUB_AUTH=github_username:github_token
docker run -e GITHUB_AUTH=${GITHUB_AUTH} -v $(pwd):/src/jenkins --rm onenashev/jenkins-changelog-generator 2.204
```
