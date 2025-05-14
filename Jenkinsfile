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
                                sh 'mkdir -p reports/dependency-check && chmod 777 reports/dependency-check'
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
                            archiveArtifacts artifacts: 'reports/dependency-check/**', allowEmptyArchive: true
                            dependencyCheckPublisher pattern: 'reports/dependency-check/dependency-check-report.xml'
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
                    sh "docker build --no-cache -t ${DOCKER_IMAGE}:${NEW_VERSION} ."
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh "echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin"
                        sh "docker push ${DOCKER_IMAGE}:${NEW_VERSION}"
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

        stage('Generate Report Summary with Ollama') {
            steps {
                script {
                    echo '📝 Génération d\'un résumé lisible des rapports avec Ollama...'
                    sh '''
                        # Vérifier que le serveur Ollama est accessible
                        curl -s http://127.0.0.1:11434 || { echo "Ollama n\\'est pas en cours d\\'exécution"; exit 1; }

                        # Vérifier que le modèle llama3.2 est disponible
                        ollama list | grep llama3.2 || { echo "Modèle llama3.2 non trouvé. Téléchargement..."; ollama pull llama3.2; }

                        # Concaténer les rapports texte pertinents
                        REPORT_FILES="reports/trivy/fs-report.txt reports/trivy/image-report.txt reports/hadolint/report.txt reports/dockle/report.txt reports/dependency-check/dependency-check-report.xml"
                        COMBINED_REPORT=""
                        for file in $REPORT_FILES; do
                            if [ -f "$file" ]; then
                                echo "=== Contenu de $file ===" >> temp_report.txt
                                head -n 50 "$file" >> temp_report.txt
                                echo "" >> temp_report.txt
                            fi
                        done

                        # Générer un résumé avec Ollama
                        ollama run llama3.2 "Résume les rapports de sécurité suivants en un texte clair et lisible en 150 mots maximum, en français. Mets en évidence les problèmes critiques et les recommandations : $(cat temp_report.txt)" > reports/ollama_summary.txt

                        # Afficher le résumé
                        cat reports/ollama_summary.txt

                        # Nettoyer le fichier temporaire
                        rm -f temp_report.txt
                    '''
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
                // 1. Archive tous les rapports
                archiveArtifacts artifacts: '**/reports/**/*', allowEmptyArchive: true

                // 2. Préparer les résumés des rapports
                def trivySummary = fileExists('reports/trivy/fs-report.txt') ?
                    readFile('reports/trivy/fs-report.txt').readLines().take(30).join("<br>") : "Aucun rapport Trivy trouvé."
                def hadolintSummary = fileExists('reports/hadolint/report.txt') ?
                    readFile('reports/hadolint/report.txt').readLines().take(30).join("<br>") : "Aucun rapport Hadolint trouvé."
                def dockleSummary = fileExists('reports/dockle/report.txt') ?
                    readFile('reports/dockle/report.txt').readLines().take(30).join("<br>") : "Aucun rapport Dockle trouvé."
                def ollamaSummary = fileExists('reports/ollama_summary.txt') ?
                    readFile('reports/ollama_summary.txt') : "Aucun résumé Ollama généré."

                try {
                    def reportFiles = findFiles(glob: '**/reports/**/*.{pdf,html,xml,txt}')
                    def attachments = reportFiles.collect { it.path }.join(',')

                    // 3. Envoi d'un email combiné avec le résumé Ollama
                    emailext(
                        subject: "Résultat Pipeline : ${currentBuild.fullDisplayName}",
                        to: 'omarhedfi99@gmail.com',
                        attachmentsPattern: '''
                            **/dependency-check-report.html,
                            **/fs-report.json,
                            **/image-report.json,
                            **/hadolint/report.*,
                            **/dockle/report.*,
                            **/ollama_summary.txt,
                            **/reports/**/*.txt,
                            !**/*.log
                        ''',
                        compressLog: true,
                        body: """
                            <html>
                            <head>
                                <style>
                                    .header { color: #2c5aa0; font-size: 18px; font-weight: bold; }
                                    .details { background: #f5f7fa; padding: 15px; border-radius: 5px; }
                                    .footer { margin-top: 20px; border-top: 1px solid #eee; padding-top: 15px; }
                                    .signature { font-weight: bold; color: #333; }
                                    .title { color: #666; font-style: italic; }
                                    pre { background: #f0f0f0; padding: 10px; border-radius: 5px; }
                                </style>
                            </head>
                            <body>
                                <div class="header">📦 Résultat du Build</div>
                                <div class="details">
                                    <p>Le build <b>${env.JOB_NAME}</b> a terminé avec le statut : <b>${currentBuild.result ?: 'SUCCESS'}</b>.</p>
                                    <ul>
                                        <li>Numéro du build : ${env.BUILD_NUMBER}</li>
                                        <li>Lien vers le build : <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></li>
                                        <li>Durée : ${currentBuild.durationString}</li>
                                        <li>Commit : ${env.GIT_COMMIT ?: 'N/A'}</li>
                                    </ul>
                                    <div class="deployment-link">
                                        <h3>🚀 Déploiement Kubernetes</h3>
                                        <p>L'application a été déployée avec succès :</p>
                                        <a href="http://192.168.49.2:30081" 
                                           style="color: #2c5aa0; font-weight: bold;">
                                           Accéder à l'application
                                        </a>
                                        <p><small>IP: 192.168.49.2:30081</small></p>
                                    </div>
                                </div>

                                <div class="footer">
                                    <h3>🔐 Résumés des Scans de Sécurité</h3>
                                    <h4>📝 Résumé Généré par Ollama</h4><pre>${ollamaSummary}</pre>
                                

                                    <p>📎 Rapports joints : Tests unitaires, Scans sécurité, Qualité code, Résumé Ollama</p>

                                    <p class="signature">Omar El Hedfi</p>
                                    <p class="title">Ingénieur DevSecOps</p>
                                </div>
                            </body>
                            </html>
                        """,
                        mimeType: 'text/html'
                    )
                } catch (err) {
                    echo "❌ Échec d'envoi d'email : ${err.getMessage()}"
                    sh '''
                        zip -r reports.zip **/reports/* || echo "Zippage échoué"
                        curl -v -F 'file=@reports.zip' https://file.io || echo "Envoi échoué"
                    '''
                }
            }
        }
    }
}
