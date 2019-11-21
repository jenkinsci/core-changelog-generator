FROM ruby

RUN apt-get update && apt-get upgrade -y && apt-get install -y jq && rm -rf /var/lib/apt/lists/*

COPY generate-jenkins-changelog.rb /jenkins-changelog-generator/bin/generate-jenkins-changelog
COPY lts-backports-changelog.rb /jenkins-changelog-generator/bin/lts-backports-changelog
COPY docker-runner.rb /jenkins-changelog-generator/bin/jenkins-changelog-generator
RUN chmod +x /jenkins-changelog-generator/bin/*

VOLUME /github/workspace

WORKDIR /github/workspace

# Forces creation
ENV CHANGELOG_YAML_PATH=/github/workspace/changelog.yaml

ENTRYPOINT ["/jenkins-changelog-generator/bin/jenkins-changelog-generator"]
