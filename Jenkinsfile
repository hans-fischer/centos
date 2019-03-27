pipeline {
  agent {
    label 'docker'
  }
  triggers {
    // Build daily
    cron('H H * * *')
  }
  options {
    ansiColor 'xterm'
    skipStagesAfterUnstable()
    timeout time: 1, unit: 'HOURS'
  }
  environment {
    CENTOS_VERSION = '7'
  }
  stages {
    stage("Build image") {
      steps {
        echo 'Building image'
        script {
          if (env.BRANCH_NAME == 'master') {
            env.TAG = env.CENTOS_VERSION
          } else {
            def matcher = env.BRANCH_NAME =~ \
              /(?<type>[a-z]+)\/((?<ticket>[A-Z]+-\d+)-)?(?<name>[a-z\-\.]+)/
            if (matcher.matches()) {
              branch = matcher.group('name')
              branch = branch.take(127 - \
                env.CENTOS_VERSION.length()).replaceAll(/(^\-+|\-+$)/, '')
              env.TAG = "${env.CENTOS_VERSION}-${branch}"
            } else {
              env.TAG = 'undefined'
            }
          }
        }

        sh """
          docker build \
            --tag quay.io/sdase/centos:${env.TAG} \
            --pull \
            --no-cache \
            --rm \
            .
        """
      }
    }
    stage("Publish image") {
      when {
        beforeAgent true
        branch 'master'
      }
      steps {
        echo 'Publishing image'

        withCredentials([usernamePassword(
            credentialsId: 'quay-io-sdase-docker-auth',
            usernameVariable: 'imageRegistryUser',
            passwordVariable: 'imageRegistryPassword')]) {
          sh """
            docker login \
              --username "${imageRegistryUser}" \
              --password "${imageRegistryPassword}" \
              quay.io

            docker push quay.io/sdase/centos:${env.TAG}
          """
        }
      }
    }
  }
}
