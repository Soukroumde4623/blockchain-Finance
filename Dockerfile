# ========================================
# STAGE 1 — Build du frontend React/Vite
# ========================================
FROM node:20-alpine AS builder

WORKDIR /app

# Copier les fichiers de dépendances en premier (cache Docker)
COPY package.json package-lock.json ./

# Installer les dépendances
RUN npm ci

# Copier le reste du code source frontend
COPY index.html tsconfig.json tsconfig.app.json tsconfig.node.json vite.config.ts postcss.config.js eslint.config.js ./
COPY src/ ./src/
COPY public/ ./public/

# Variable d'environnement pour l'URL de l'API
# En production Docker, nginx proxy vers le backend
ARG VITE_API_URL=/api
ENV VITE_API_URL=$VITE_API_URL

# Build de production
RUN npm run build

# ========================================
# STAGE 2 — Serveur nginx léger
# ========================================
FROM nginx:alpine AS production

# Copier la config nginx personnalisée
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# Copier les fichiers buildés depuis le stage précédent
COPY --from=builder /app/dist /usr/share/nginx/html

# Exposer le port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
