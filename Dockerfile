# Étape 1 - Utiliser une image Nginx officielle comme base
FROM nginx:alpine

# Étape 2 - Supprimer la configuration par défaut de Nginx
RUN rm -rf /etc/nginx/conf.d/default.conf

# Étape 3 - Configurer Nginx pour écouter sur le port 81
COPY nginx-custom.conf /etc/nginx/conf.d/default.conf

# Étape 4 - Copier les fichiers du site web dans le conteneur
COPY . /usr/share/nginx/html

# Étape 5 - Exposer le port 81
EXPOSE 81

# Étape 6 - Démarrer Nginx
CMD ["nginx", "-g", "daemon off;"]
