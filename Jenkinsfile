// CentOS image

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
    lock resource: 'quay.io/sdase/centos'
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
