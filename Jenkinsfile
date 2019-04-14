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
@Library('jenkins-library@feat/pipeline-generator') _

pipeline {
  agent none
  triggers {
    // Build daily
    cron('H H * * *')
  }
  options {
    ansiColor 'xterm'
    skipStagesAfterUnstable()
    timeout time: 1, unit: 'HOURS'
  }
  stages {
    stage("Build container images") {
      agent {
        docker {
          image 'quay.io/sdase/centos-development:7'
          args '--privileged -u root:root'
        }
      }
      steps {
        sh """
          BUILD_EXPORT_OCI_ARCHIVES=true ./build.sh
          chown --reference=${env.WORKSPACE}/Jenkinsfile *.tar
        """
        stash name: 'oci-archives', includes: '*.tar'
      }
    }
    stage('Publish container images') {
      when {
        beforeAgent true
        branch 'master'
      }
      agent {
        docker {
          image 'quay.io/sdase/centos-development:7'
          args '--privileged -u root:root'
        }
      }
      environment {
        QUAY_CREDS = credentials('quay-io-sdase-docker-auth')
      }
      steps {
        unstash 'oci-archives'
        lock('centos') {
          milestone 0
          script {
            findFiles(glob: '*.tar').each { file ->
              echo "File: «file»"

              def spec = skopeo.inspect image: "oci-archive:${file}"
              def version = spec['Labels']['org.opencontainers.image.version']
              echo "Image version: «${version}»"

              def matcher = version =~ /(?<semVer>\d+(.\d+)*)(?<suffix>-(.+))?/
              if( matcher.matches() ) {
                def semVer = matcher.group('semVer')
                def suffix = matcher.group('suffix')
                def tokens = semVer.tokenize('.')
                def tags = (1..tokens.size()).collect {
                  "${tokens.subList(0, it).join('.')}${suffix ?: ''}"
                }
                tags.each { tag ->
                  skopeo.copy(
                    from: "oci-archive:${file}",
                    to: "docker://quay.io/sdase/centos:${tag}",
                    options: [
                      destCreds: env.QUAY_CREDS
                    ]
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}








pipeline {
  agent none
  options {
    ansiColor 'xterm'
    skipStagesAfterUnstable()
    timeout time: 1, unit: 'HOURS'
  }
  stages {
    stage("Build container image") {
      agent {
        docker {
          image 'quay.io/sdase/centos-development:7.6.1810'
          args '--privileged -u root:root'
        }
      }
      steps {
        sh """
          set -x
          ./build
          buildah push centos oci-archive:oci-archive.tar:centos:build
          chown --recursive --reference=./build oci-archive.tar
        """
        stash name: 'oci-archive', includes: 'oci-archive.tar'
      }
    }
    stage("Publish container image") {
      agent {
        docker {
          image 'quay.io/sdase/centos-development:7.6.1810'
          args '--privileged -u root:root'
        }
      }
      environment {
        QUAY_CREDS = credentials('quay-io-sdase-docker-auth')
      }
      steps {
        unstash 'oci-archive'
        sh """
          skopeo copy \
            --dest-creds "${env.QUAY_CREDS}" \
            oci-archive:oci-archive.tar:centos:build \
            docker://quay.io/sdase/centos:from-buildah
        """
      }
    }
  }
}
