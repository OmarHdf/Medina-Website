pipeline {
    agent any

    environment {
        SONARQUBE_URL = 'http://localhost:9000'
        SONARQUBE_TOKEN = credentials('SONARQUBE_TOKEN')
        GITHUB_REPO = 'https://github.com/OmarHdf/Medina-Website.git'
        DOCKER_IMAGE = "medina-site"
        K8S_DEPLOYMENT = "medina-deployment.yml"  
        NEW_VERSION = "1.0.${BUILD_NUMBER}"
    }

    stages {
        
        stage('Tool Check & Install') {
            steps {
                script {
                    echo '🔧 Vérification des outils...'
                    sh 'docker --version || echo "Docker manquant"'
                    sh 'kubectl version --client'
                    sh 'minikube version'
                }
            }
        }

        
        stage('Clean Workspace') {
            steps { cleanWs() }
        }

       
        stage('Checkout Code') {
            steps {
                git(
                    url: "${GITHUB_REPO}",
                    credentialsId: 'GITHUB_TOKEN',
                    branch: 'main'
                )
            }
        }

       
        stage('Ensure Services Are Running') {
            steps {
                sh '''
                    docker-compose up -d sonarqube postgres
                '''
            }
        }

        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube_Scanner') {
                    sh """
                        sonar-scanner \
                        -Dsonar.projectKey=Medina-Website \
                        -Dsonar.login=${SONARQUBE_TOKEN} \
                        -Dsonar.projectVersion=${NEW_VERSION}
                    """
                }
            }
        }

      
        stage('Security Scans') {
            parallel {
                stage('Trivy FS') {
                    steps { sh 'trivy fs --security-checks vuln,config .' }
                }
                stage('Hadolint') {
                    steps { sh 'docker run --rm -i hadolint/hadolint < Dockerfile' }
                }
            }
        }

        
        stage('Docker Build & Push') {
            steps {
                script {
                    sh """
                        eval \$(minikube docker-env)
                        docker build -t ${DOCKER_IMAGE}:${NEW_VERSION} .
                    """
                }
            }
        }

     
        stage('Image Security Scans') {
            steps {
                sh "trivy image ${DOCKER_IMAGE}:${NEW_VERSION}"
            }
        }

       
        stage('Déploiement Kubernetes') {
            steps {
                script {
                    sh """
                        minikube status || minikube start
                        kubectl apply -f ${K8S_DEPLOYMENT}
                        kubectl rollout status deployment/medina-website-deployment
                    """
                }
            }
        }

       
        stage('Get Application URL') {
            steps {
                script {
                    env.APP_URL = sh(script: 'minikube service medina-service --url', returnStdout: true).trim()
                    echo "🌐 Application disponible: ${env.APP_URL}"
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts 'reports/**/*'
        }
        success {
            emailext(
                subject: "SUCCÈS: Medina-Website v${NEW_VERSION}",
                body: "URL: ${env.APP_URL}",
                to: 'omarhedfi99@gmail.com'
            )
        }
        failure {
            emailext(
                subject: "ÉCHEC: Déploiement Medina-Website",
                to: 'omarhedfi99@gmail.com',
                attachLog: true
            )
        }
    }
}
