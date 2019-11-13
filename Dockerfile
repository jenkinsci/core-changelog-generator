FROM ruby

COPY generate-jenkins-changelog.rb /usr/local/bin/generate-jenkins-changelog
COPY lts-backports-changelog.rb /usr/local/bin/lts-backports-changelog
COPY docker-runner.rb /usr/local/bin/jenkins-changelog-generator

VOLUME /src/jenkins

WORKDIR /src/jenkins

# Forces creationg 
ENV CHANGELOG_YAML_PATH=/src/jenkins/changelog.yaml

ENTRYPOINT ["jenkins-changelog-generator"]
