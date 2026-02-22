FROM node:20-alpine

WORKDIR /app

# Copier les fichiers de dépendances
COPY package.json package-lock.json* ./

# Installer les dépendances
RUN npm ci --production

# Copier le code du backend
COPY server.js fabric-network.js setup-wallet.js ./
COPY config/ ./config/

# Port du backend
EXPOSE 4000

# Variables d'environnement par défaut
ENV PORT=4000
ENV CHANNEL_NAME=tokenchannel
ENV CHAINCODE_NAME=token
ENV NODE_ENV=production
ENV WALLET_PATH=./wallet
ENV CONFIG_PATH=./config
ENV FABRIC_NETWORK_PATH=/fabric-network

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -q --spider http://localhost:4000/api/health || exit 1

CMD ["node", "server.js"]
