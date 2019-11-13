FROM ruby

COPY generate-jenkins-changelog.rb /jenkins-changelog-generator/bin/generate-jenkins-changelog
COPY lts-backports-changelog.rb /jenkins-changelog-generator/bin/lts-backports-changelog
COPY docker-runner.rb /jenkins-changelog-generator/bin/jenkins-changelog-generator

VOLUME /github/workspace

WORKDIR /github/workspace

# Forces creationg 
ENV CHANGELOG_YAML_PATH=/github/workspace/changelog.yaml
ENV PATH=${PATH}:/jenkins-changelog-generator/bin

ENTRYPOINT ["jenkins-changelog-generator"]
