🏗️ Medina Website - Pipeline CI/CD DevSecOps
📌 Description du Projet
Medina Website est un projet web moderne conçu pour être déployé de manière sécurisée, automatisée et contrôlée à l’aide d’un pipeline CI/CD robuste basé sur Jenkins. Ce projet illustre l'intégration complète de pratiques DevSecOps, combinant développement, sécurité, et opérations pour garantir un cycle de vie applicatif rapide, fiable et sécurisé.

L'objectif principal est d'automatiser toutes les étapes du cycle de vie logiciel : de la récupération du code source jusqu'au déploiement en production sur Kubernetes, en incluant des analyses de sécurité avancées à chaque étape.

⚙️ Technologies & Outils utilisés
Jenkins : Orchestration du pipeline CI/CD

Docker : Conteneurisation de l’application

DockerHub : Registre d'images Docker

Kubernetes (via Minikube) : Orchestration et déploiement de l’application

SonarQube : Analyse statique de la qualité du code

OWASP Dependency-Check : Détection des dépendances vulnérables

Trivy : Scans de vulnérabilités dans le système de fichiers et les images Docker

Hadolint : Analyse du Dockerfile

Dockle : Analyse de sécurité des images Docker

Ollama (llama3.2) : Résumé intelligent des rapports de sécurité en langage naturel

🚀 Fonctionnement du Pipeline CI/CD
Le pipeline Jenkins est découpé en plusieurs étapes structurées :

1. 🔍 Vérification des outils & Nettoyage
Vérifie la présence de Docker, kubectl, et Minikube.

Nettoie l’environnement de travail Jenkins pour un build propre.

2. 📥 Récupération du code
Téléchargement du code source depuis GitHub.

3. 🧱 Vérification des services
Démarre automatiquement SonarQube et PostgreSQL via Docker Compose si non disponibles.

4. 📊 Analyse SonarQube
Analyse la qualité du code, recherche de bugs, code smells, duplications, complexité...

5. 🛡️ Scans de sécurité (en parallèle)
Trivy FS : Analyse des fichiers source du projet.

Hadolint : Vérifie la conformité du Dockerfile.

Dependency-Check : Recherche des CVE connues dans les dépendances.

6. 🔨 Construction & Scan de l'image Docker
Construction sans cache d’une image Docker versionnée.

Trivy Image : Scan de vulnérabilités sur l’image.

Dockle : Analyse de conformité de l’image avec les bonnes pratiques.

7. 📤 Push de l’image Docker
Authentification DockerHub et push de l’image versionnée.

8. 🧠 Résumé des rapports avec IA
Génération d’un résumé lisible en français des résultats des scans grâce à Ollama utilisant le modèle llama3.2.

9. 🧾 Préparation et déploiement Kubernetes
Substitution dynamique de la version dans le fichier medina-deployment.yml.

Déploiement sur Minikube avec monitoring du rollout.

10. 📈 Post-déploiement
Récupération de l’état des pods et affichage de l’URL d’accès à l’application.

📁 Structure des rapports
Tous les résultats des scans sont sauvegardés sous le dossier reports/ :

pgsql
Copier
Modifier
reports/
├── trivy/
│   ├── fs-report.txt
│   ├── image-report.txt
├── hadolint/
│   ├── report.txt
├── dependency-check/
│   ├── dependency-check-report.xml
│   ├── dependency-check.log
├── dockle/
│   ├── report.txt
├── ollama_summary.txt
📬 Notifications & Archivage
À la fin du pipeline :

Les rapports sont archivés automatiquement dans Jenkins.

Le résumé IA est affiché dans la console pour faciliter la lecture.

Le pipeline peut être facilement étendu pour envoyer des emails ou intégrer Slack.
