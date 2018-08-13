#!groovy

/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018
 */


def isPullRequest = env.BRANCH_NAME.startsWith('PR-')

def opts = []
// keep last 20 builds for regular branches, no keep for pull requests
opts.push(buildDiscarder(logRotator(numToKeepStr: (isPullRequest ? '' : '20'))))
// disable concurrent build
opts.push(disableConcurrentBuilds())
// set upstream triggers
if (env.BRANCH_NAME == 'master') {
  opts.push(pipelineTriggers([
    upstream(threshold: 'SUCCESS', upstreamProjects: '/zlux,/atlas-wlp-package-pipeline/master')
  ]))
}

// define custom build parameters
def customParameters = []
customParameters.push(credentials(
  name: 'PAX_SERVER_CREDENTIALS_ID',
  description: 'The server credential used to create PAX file',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'TestAdminzOSaaS2',
  required: true
))
customParameters.push(string(
  name: 'PAX_SERVER_IP',
  description: 'The server IP used to create PAX file',
  defaultValue: '172.30.0.1',
  trim: true
))
customParameters.push(string(
  name: 'ARTIFACTORY_SERVER',
  description: 'Artifactory server, should be pre-defined in Jenkins configuration',
  defaultValue: 'gizaArtifactory',
  trim: true
))
customParameters.push(string(
  name: 'ZOWE_VERSION',
  description: 'Zowe version number',
  defaultValue: '0.9.0',
  trim: true
))
opts.push(parameters(customParameters))

// set build properties
properties(opts)

node ('jenkins-slave') {
  currentBuild.result = 'SUCCESS'

  try {

    stage('checkout') {
      // checkout source code
      checkout scm

      // check if it's pull request
      echo "Current branch is ${env.BRANCH_NAME}"
      if (isPullRequest) {
        echo "This is a pull request"
      }
    }

    stage('prepare') {
      echo 'preparing PAX workspace folder...'

      // download artifactories
      def server = Artifactory.server params.ARTIFACTORY_SERVER
      def downloadSpec = readFile "artifactory-download-spec.json"
      downloadSpec = downloadSpec.replaceAll(/\{ARTIFACTORY_VERSION\}/, params.ZOWE_VERSION)
      server.download(downloadSpec)

      // prepare folder
      // - pax-workspace/content holds binary files
      // - pax-workspace/ascii holds ascii files and will be converted to IBM-1047 encoding
      sh 'mkdir -p pax-workspace/ascii/scripts'
      sh 'mkdir -p pax-workspace/ascii/install'
      sh 'mkdir -p pax-workspace/ascii/files'
      sh "mkdir -p pax-workspace/content/zowe-${params.ZOWE_VERSION}/files"
      // copy from current github source
      sh "cp -R files/* pax-workspace/content/zowe-${params.ZOWE_VERSION}/files"
      sh "rsync -rv --include '*.json' --include '*.html' --include '*.jcl' --include '*.template' --exclude '*.zip' --exclude '*.png' --exclude '*.tgz' --exclude '*.tar.gz' --exclude '*.pax' --prune-empty-dirs --remove-source-files pax-workspace/content/zowe-${params.ZOWE_VERSION}/files pax-workspace/ascii"
      sh 'cp -R install/* pax-workspace/ascii/install'
      sh 'cp -R scripts/* pax-workspace/ascii/scripts'
      // tar ascii files
      // debug purpose, list all ascii files before tar
      sh 'find ./pax-workspace/ascii -print'
      sh 'tar -c -f pax-workspace/ascii.tar -C pax-workspace/ ascii'
      sh 'tar -c -f pax-workspace/api-mediation.tar -C pax-workspace/ mediation'
      sh 'rm -fr pax-workspace/ascii'

      // debug purpose, list all files in workspace
      sh 'find ./pax-workspace -print'
    }

    stage('package') {
      // scp files and ssh to z/OS to pax workspace
      echo "creating pax file from workspace..."
      timeout(time: 30, unit: 'MINUTES') {
        createPax('zowe-install-packaging', "zowe.pax",
                  params.PAX_SERVER_IP, params.PAX_SERVER_CREDENTIALS_ID,
                  './pax-workspace', '/zaas1/buildWorkspace', '-x os390',
                  ['ZOWE_VERSION':params.ZOWE_VERSION])
      }
    }

    stage('publish') {
      echo 'publishing pax file to artifactory...'

      def releaseIdentifier = getReleaseIdentifier()
      def buildIdentifier = getBuildIdentifier(true, '__EXCLUDE__', true)

      def server = Artifactory.server params.ARTIFACTORY_SERVER
      def uploadSpec = readFile "artifactory-upload-spec.json"
      uploadSpec = uploadSpec.replaceAll(/\{ARTIFACTORY_VERSION\}/, params.ZOWE_VERSION)
      uploadSpec = uploadSpec.replaceAll(/\{RELEASE_IDENTIFIER\}/, releaseIdentifier)
      uploadSpec = uploadSpec.replaceAll(/\{BUILD_IDENTIFIER\}/, buildIdentifier)
      def buildInfo = Artifactory.newBuildInfo()
      server.upload spec: uploadSpec, buildInfo: buildInfo
      server.publishBuildInfo buildInfo
    }

    stage('done') {
      // send out notification
      emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} success.\n\nCheck detail: ${env.BUILD_URL}" ,
          subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} success",
          recipientProviders: [
            [$class: 'RequesterRecipientProvider'],
            [$class: 'CulpritsRecipientProvider'],
            [$class: 'DevelopersRecipientProvider'],
            [$class: 'UpstreamComitterRecipientProvider']
          ]
    }

  } catch (err) {
    currentBuild.result = 'FAILURE'

    // catch all failures to send out notification
    emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed.\n\nError: ${err}\n\nCheck detail: ${env.BUILD_URL}" ,
        subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed",
        recipientProviders: [
          [$class: 'RequesterRecipientProvider'],
          [$class: 'CulpritsRecipientProvider'],
          [$class: 'DevelopersRecipientProvider'],
          [$class: 'UpstreamComitterRecipientProvider']
        ]

    throw err
  }
}
