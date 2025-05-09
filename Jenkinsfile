pipeline {
    agent any

      environment {
        SONARQUBE_URL = 'http://localhost:9000'
        SONARQUBE_TOKEN = credentials('SONARQUBE_TOKEN')
        GITHUB_TOKEN = credentials('GITHUB_TOKEN')
        DOCKER_IMAGE = "omarelhedfi/medina-site"
        VERSION_FILE = 'version.txt'
        POSTGRES_USER = 'sonar'
        POSTGRES_PASSWORD = 'sonar'
        POSTGRES_DB = 'sonarqube-postgres'
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
        checkout([
            $class: 'GitSCM',
            branches: [[name: 'main']],
            extensions: [],
            userRemoteConfigs: [[
                url: 'https://github.com/OmarHdf/Medina-Website.git',
                credentialsId: 'GITHUB_TOKEN'  
            ]]
        ])
    }
}

        
       stage('Ensure Services Are Running') {
            steps {
                script {
                    echo '🚀 Vérification que les services sont en marche...'
                    sh '''
                        if [ ! "$(docker ps -q -f name=sonarqube)" ]; then
                            echo "SonarQube est arrêté, redémarrage..."
                            docker-compose up -d sonarqube
                        else
                            echo "SonarQube est déjà en cours d'exécution."
                        fi
                        
                        if [ ! "$(docker ps -q -f name=sonarqube-postgres)" ]; then
                            echo "PostgreSQL est arrêté, redémarrage..."
                            docker-compose up -d postgres
                        else
                            echo "PostgreSQL est déjà en cours d'exécution."
                        fi
                    '''
                }
            }
        }
       
          stage('SonarQube Analysis') {
            steps {
                echo '🔍 Analyse du code avec SonarQube...'
                withSonarQubeEnv('SonarQube_Scanner') {
                    script {
                        def scannerHome = tool name: 'SonarQube_Scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=Medina-Website \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=${SONARQUBE_URL} \
                            -Dsonar.login=${SONARQUBE_TOKEN} \
                            -Dsonar.projectVersion=${NEW_VERSION} \
                            -X
                        """
                    }
                }
            }
        }


       
       
        stage('Security Scans') {
            parallel {
                stage('Trivy File System Scan') {
                    steps {
                        script {
                            echo '🛡️ Scan des fichiers avec Trivy...'
                            sh '''
                                mkdir -p reports/trivy
                                trivy fs --scanners vuln,misconfig --format json --output reports/trivy/fs-report.json .
                                trivy fs --scanners vuln,misconfig --format table --output reports/trivy/fs-report.txt .
                            '''
                        }
                    }
                }

                stage('Hadolint Dockerfile Check') {
                    steps {
                        script {
                            echo '🔎 Vérification du Dockerfile avec Hadolint...'
                            sh '''
                                mkdir -p reports/hadolint
                                docker run --rm -i hadolint/hadolint < Dockerfile > reports/hadolint/report.txt 2>&1 || true
                                echo '{"issues":[' > reports/hadolint/report.json
                                grep -o 'DL[0-9]*' reports/hadolint/report.txt | awk '{print "{\"id\":\""$1"\"},"}' >> reports/hadolint/report.json
                                sed -i '$ s/,$//' reports/hadolint/report.json
                                echo ']}' >> reports/hadolint/report.json
                            '''
                        }
                    }
                }

            stage('Dependency-Check') {
    steps {
        script {
            withCredentials([string(credentialsId: 'NVD_API_KEY', variable: 'NVD_KEY')]) {
                // Create output directory with proper permissions
                sh 'mkdir -p reports/dependency-check && chmod 777 reports/dependency-check'
                
                // Run analysis with proper credential handling
                sh '''
                docker run --rm \
                    -v "${WORKSPACE}:/scan" \
                    -v "dependency-check-cache:/usr/share/dependency-check/data" \
                    -e data.dependencycheck.nvd.api.key=${NVD_KEY} \
                    -e JAVA_OPTS="-Xmx4g" \
                    owasp/dependency-check:7.4.4 \
                    --scan /scan \
                    --format ALL \
                    --out /scan/reports/dependency-check \
                    --failOnCVSS 0 \
                    --disableRetireJS \
                    --disableNodeAudit \
                    --disableYarnAudit \
                    --log /scan/reports/dependency-check/dependency-check.log
                '''
            }
        }
    }
    post {
        always {
            // Archive reports regardless of success/failure
            archiveArtifacts artifacts: 'reports/dependency-check/**', allowEmptyArchive: true
            
            // Publish Dependency-Check results
            dependencyCheckPublisher pattern: 'reports/dependency-check/dependency-check-report.xml'
            
            // Display log if exists
            script {
                if (fileExists('reports/dependency-check/dependency-check.log')) {
                    echo 'Dependency-Check Log:'
                    sh 'tail -n 100 reports/dependency-check/dependency-check.log || true'
                }
            }
        }
    }
}
            }
}
  

        
          stage('Docker Build & Push') {
            steps {
                script {
                    echo '🔨 Construction et push de l\'image Docker...'
                    sh " docker build --no-cache -t ${DOCKER_IMAGE}:${NEW_VERSION} ."
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh "echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin"
                        sh " docker push ${DOCKER_IMAGE}:${NEW_VERSION}"
                    }
                }
            }
        }



        
        stage('Image Security Scans') {
            parallel {
                stage('Trivy Image Scan') {
                    steps {
                        script {
                            echo "🛡️ Scan de l'image Docker avec Trivy..."
                            sh """
                                mkdir -p reports/trivy
                                trivy image \
                                    --format json \
                                    --output reports/trivy/image-report.json \
                                    ${DOCKER_IMAGE}:${NEW_VERSION}
                                    
                                trivy image \
                                    --format table \
                                    --output reports/trivy/image-report.txt \
                                    ${DOCKER_IMAGE}:${NEW_VERSION}
                            """
                        }
                    }
                }

                stage('Dockle Scan') {
                    steps {
                        script {
                            echo "🔍 Scan de l'image avec Dockle..."
                            sh """
                                mkdir -p reports/dockle
                                docker run --rm \
                                    -v /var/run/docker.sock:/var/run/docker.sock \
                                    -v "${WORKSPACE}/reports/dockle:/out" \
                                    goodwithtech/dockle \
                                    -f json -o /out/report.json \
                                    ${DOCKER_IMAGE}:${NEW_VERSION} || true

                                docker run --rm \
                                    -v /var/run/docker.sock:/var/run/docker.sock \
                                    goodwithtech/dockle \
                                    ${DOCKER_IMAGE}:${NEW_VERSION} > reports/dockle/report.txt 2>&1 || true
                            """
                        }
                    }
                }
            }
        }

   stage('Prepare Deployment') {
    steps {
        script {
           String processedYaml = readFile('medina-deployment.yml').replace('${NEW_VERSION}', env.NEW_VERSION)
            writeFile file: 'medina-deployment-processed.yml', text: processedYaml
        }
    }
}

stage('Déploiement Kubernetes') {
    steps {
        script {
            sh """
                kubectl apply -f medina-deployment-processed.yml
                kubectl rollout status deployment/medina-website --timeout=300s
            """
        }
    }
}
        stage('Post-Déploiement') {
    steps {
        script {
            sh '''
                echo "=== RAPPORT DE SANTÉ ==="
                kubectl get pods -o wide
                

                echo "=== APPLICATION ACCESS ==="
                NODE_PORT=$(kubectl get service medina-service -o=jsonpath='{.spec.ports[0].nodePort}')
                NODE_IP=$(minikube ip)
                echo "App running at: http://$NODE_IP:$NODE_PORT"
            '''
        }
    }
}

    }

       post {
        always {
            script {
                // 1. Archivez tous les rapports
                archiveArtifacts artifacts: '**/reports/**/*', allowEmptyArchive: true
                
                // 2. Envoi d'email avec pièces jointes
                try {
                    def reportFiles = findFiles(glob: '**/reports/**/*.{pdf,html,xml,txt}')
                    def attachments = reportFiles.collect { it.path }.join(',')
                    
                    emailext(
    subject: "Build ${currentBuild.result ?: 'SUCCESS'} - ${env.JOB_NAME}",
    body: """
    <html>
    <head>
        <style>
            .header { color: #2c5aa0; font-size: 18px; font-weight: bold; }
            .details { background: #f5f7fa; padding: 15px; border-radius: 5px; }
            .footer { margin-top: 20px; border-top: 1px solid #eee; padding-top: 15px; }
            .signature { font-weight: bold; color: #333; }
            .title { color: #666; font-style: italic; }
        </style>
    </head>
    <body>
        <div class="header">Résultat du Build</div>
        
        <div class="details">
            <p>Le build <b>${env.JOB_NAME}</b> a réussi.</p>
            
            <h3>Détails techniques</h3>
            <ul>
                <li>Numéro du build: ${env.BUILD_NUMBER}</li>
                <li>Lien vers le build: <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></li>
                <li>Durée: ${currentBuild.durationString}</li>
                <li>Commit: ${env.GIT_COMMIT ?: 'N/A'}</li>
            </ul>
             <div class="deployment-link">
            <h3>Accès au Déploiement</h3>
            <p>L'application a été déployée avec succès sur Kubernetes :</p>
            <a href="http://192.168.58.2:30081" 
               style="color: #2c5aa0; font-weight: bold;">
               Accéder à l'application
            </a>
            <p><small>IP: 192.168.58.2:30081</small></p>
        </div>
        </div>

        <div class="footer">
            <p>Veuillez trouver ci-joint les rapports techniques :</p>
            <ul>
                <li>Rapports de tests unitaires</li>
                <li>Analyse de sécurité</li>
                <li>Métriques de qualité</li>
            </ul>
            
            
            <p class="signature">Omar El Hedfi</p>
            <p class="title">Ingénieur DevSecOps</p>
        </div>
    </body>
    </html>
    """,
    to: 'omarhedfi99@gmail.com',
    attachmentsPattern: '''
        **/dependency-check-report.html,
        **/fs-report.json,
        **/image-report.json,
        **/hadolint/report.*,
        **/dockle/report.*,
        !**/*.log  // Exclure les logs si trop volumineux
    ''',
    compressLog: true
)
                } catch (err) {
                    echo "❌ Échec d'envoi d'email: ${err.getMessage()}"
                    // Solution alternative - stockage des rapports
                    sh """
                        zip -r reports.zip **/reports/*
                        curl -v -F 'file=@reports.zip' https://file.io
                    """
                }
            }
        }
    }
}
