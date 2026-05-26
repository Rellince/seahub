pipeline {
  agent { label 'linux' }

  options {
    timeout(time: 60, unit: 'MINUTES')
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    string(
      name: 'BASE_TAG',
      defaultValue: '13.0.21',
      description: 'Upstream seafileltd/seafile-mc base tag'
    )
  }

  triggers {
    pollSCM('H/5 * * * *')
  }

  environment {
    REGISTRY_OWNER = 'andisancans18'
    IMAGE_REPO     = 'rellince'
    SHA_SHORT      = "${env.GIT_COMMIT?.take(12) ?: 'manual'}"
    IMAGE_TAG      = "seahub-${env.BUILD_NUMBER}-${SHA_SHORT}"
  }

  stages {
    stage('checkout') {
      steps { checkout scm }
    }

    stage('build') {
      steps {
        sh '''
          set -e
          docker build \\
            --pull \\
            --build-arg BASE_TAG=${BASE_TAG} \\
            -f .docker/seahub/Dockerfile.prod \\
            -t ${REGISTRY_OWNER}/${IMAGE_REPO}:${IMAGE_TAG} \\
            -t ${REGISTRY_OWNER}/${IMAGE_REPO}:seahub-latest \\
            .
        '''
      }
    }

    stage('push') {
      when {
        anyOf {
          branch 'rellince'
          expression { env.BRANCH_NAME == null }   // also push on non-multibranch jobs
        }
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub',
          usernameVariable: 'DH_USER',
          passwordVariable: 'DH_PASS'
        )]) {
          sh '''
            set -e
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            docker push ${REGISTRY_OWNER}/${IMAGE_REPO}:${IMAGE_TAG}
            docker push ${REGISTRY_OWNER}/${IMAGE_REPO}:seahub-latest
            docker logout
          '''
        }
      }
    }

    stage('deploy') {
      when {
        anyOf {
          branch 'rellince'
          expression { env.BRANCH_NAME == null }
        }
      }
      steps {
        build job: 'seafile-deploy',
              parameters: [string(name: 'IMAGE_TAG', value: env.IMAGE_TAG)],
              wait: false,
              propagate: false
      }
    }
  }

  post {
    always {
      sh 'docker image prune -f || true'
      cleanWs()
    }
    failure { echo "Build ${env.BUILD_NUMBER} failed: ${env.BUILD_URL}" }
  }
}
