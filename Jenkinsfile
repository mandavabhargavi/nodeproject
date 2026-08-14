pipeline {
  agent any
  stages {
    stage('Build') {
      steps {
        sh 'npm run build'
      }
    }
   stage('Docker Build') {
            steps {
                sh 'docker build -t nodeproject .'
            }
   }
  }
}

