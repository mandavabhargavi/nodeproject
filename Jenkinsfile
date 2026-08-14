pipeline {
  agent any
  stages {
    stage('Build') {
      steps {
        sh 'npm run build'
      }
    }
    stage('test') {
      steps {
        sh 'npm test'
      }
    }
  }
}

