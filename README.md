# 🔗 Blockchain Dashboard — Hyperledger Fabric

Dashboard d'administration pour un réseau **Hyperledger Fabric**, avec gestion des comptes, utilisateurs, transactions et monitoring en temps réel.

![Stack](https://img.shields.io/badge/React_19-TypeScript-blue?logo=react)
![Fabric](https://img.shields.io/badge/Hyperledger_Fabric-2.5-orange?logo=hyperledger)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)
![License](https://img.shields.io/badge/License-MIT-green)


## 📋 Table des matières

- [Aperçu](#-aperçu)
- [Architecture](#-architecture)
- [Démarrage rapide (Docker)](#-démarrage-rapide-docker)
- [Installation complète](#-installation-complète)
- [Structure du projet](#-structure-du-projet)
- [Scripts d'extension réseau](#-scripts-dextension-réseau)
- [API Backend](#-api-backend)
- [Technologies](#-technologies)

---

## 🖥️ Aperçu

| Fonctionnalité | Description |
|---|---|
| **Dashboard** | Vue d'ensemble avec statistiques, graphiques TPS, jauges temps réel |
| **Comptes** | Création, modification, blocage/déblocage, mint et transfert de tokens |
| **Utilisateurs** | CRUD complet, activation/désactivation |
| **Transactions** | Historique complet avec filtres, table paginée |
| **Extension réseau** | Scripts pour ajouter orgs, peers, orderers dynamiquement |

---

## 🏗️ Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────────────────┐
│   Frontend   │────▶│   Backend    │────▶│   Hyperledger Fabric Network │
│  React/Vite  │:80  │  Express.js  │:4000│  3 Orderers (Raft)           │
│  nginx proxy │     │  fabric-sdk  │     │  2 Orgs × 2 Peers           │
└──────────────┘     └──────────────┘     │  CouchDB + TLS CA           │
                                          │  Go Chaincode (CCAAS)        │
                                          └──────────────────────────────┘
```

---

## 🐳 Démarrage rapide (Docker)

### Prérequis
- [Docker](https://docs.docker.com/get-docker/) & Docker Compose

### 🔹 Option 1 — Frontend seul (preview du dashboard)

> **Aucune installation supplémentaire requise.** Parfait pour voir l'interface.

```bash
git clone https://github.com/<VOTRE_USERNAME>/blockchain-Finance.git
cd blockchain-Finance

# Lancer le frontend
docker-compose -f docker-compose.frontend.yml up --build
```

Ouvrir **http://localhost:3000** dans le navigateur.

### 🔹 Option 2 — Frontend + Backend + Fabric

> Nécessite que le réseau Fabric soit déployé au préalable.

```bash
# 1. Déployer le réseau Fabric
cd hyperledger-fabric-network
bash setup.sh

# 2. Lancer le dashboard complet
cd ..
docker-compose up --build
```

- Frontend : **http://localhost:3000**
- Backend API : **http://localhost:4000/api/health**

---

## 🔧 Installation complète (développement)

### Prérequis

- **Node.js** 20.x+
- **Docker** & Docker Compose
- **Go** 1.21+ (pour le chaincode)
- **Hyperledger Fabric** binaries 2.5.x

### Étapes

```bash
# 1. Cloner le repo
git clone https://github.com/<VOTRE_USERNAME>/blockchain-Finance.git
cd blockchain-Finance

# 2. Déployer le réseau Hyperledger Fabric
cd hyperledger-fabric-network
bash setup.sh
cd ..

# 3. Installer les dépendances frontend
npm install

# 4. Configurer le backend
cd backend
npm install
cp .env.example .env    # Adapter si nécessaire
cd ..

# 5. Lancer en développement
# Terminal 1 — Backend
cd backend && node server.js

# Terminal 2 — Frontend (avec hot-reload)
npm run dev
```

- Frontend dev : **http://localhost:5173**
- Backend API : **http://localhost:4000**

---

## 📁 Structure du projet

```
blockchain-Finance/
├── src/                        # Code source React/TypeScript
│   ├── App.tsx                 # Routes principales
│   ├── components/             # Composants réutilisables
│   │   ├── Sidebar.tsx         # Navigation latérale
│   │   ├── StatCard.tsx        # Cartes statistiques
│   │   ├── TpsPerPeerChart.tsx # Graphique TPS par peer
│   │   ├── CircularGauge.tsx   # Jauges circulaires
│   │   └── ...
│   ├── pages/                  # Pages du dashboard
│   │   ├── Dashboard.tsx       # Page d'accueil
│   │   ├── Account.tsx         # Gestion des comptes
│   │   ├── Users.tsx           # Gestion des utilisateurs
│   │   └── Transactions.tsx    # Historique transactions
│   ├── context/                # Context React (état global)
│   │   ├── BlockchainContext.tsx
│   │   ├── SidebarContext.tsx
│   │   └── ThemeContext.tsx
│   └── services/
│       └── blockchain-api.ts   # Service API
│
├── backend/                    # API Express.js
│   ├── server.js               # Serveur Express + routes
│   ├── fabric-network.js       # Service Fabric SDK
│   ├── config/                 # Connection profiles (auto-découverte)
│   │   ├── connection-org1.json
│   │   └── connection-org2.json
│   ├── .env.example            # Template variables d'environnement
│   └── Dockerfile              # Image Docker backend
│
├── hyperledger-fabric-network/ # Réseau Fabric
│   ├── setup.sh                # Script de déploiement complet
│   ├── chaincode/token/        # Smart contract Go
│   ├── builders/ccaas/         # Chaincode-as-a-service builder
│   └── docker-compose*.yaml    # Conteneurs Fabric
│
├── scripts/                    # Scripts d'extension réseau
│   ├── extend-network.sh       # Menu interactif
│   ├── add-org.sh              # Ajouter une organisation
│   ├── add-peer.sh             # Ajouter un peer
│   └── add-orderer.sh          # Ajouter un orderer Raft
│
├── docker/
│   └── nginx.conf              # Config nginx pour le frontend
│
├── Dockerfile                  # Multi-stage build frontend
├── docker-compose.yml          # Stack complète (frontend + backend)
├── docker-compose.frontend.yml # Frontend seul (preview)
├── vite.config.ts              # Config Vite (dev + proxy)
└── package.json                # Dépendances frontend
```

---

## 🌐 Scripts d'extension réseau

Le réseau Fabric est extensible dynamiquement grâce aux scripts dans `scripts/` :

```bash
# Menu interactif
bash scripts/extend-network.sh

# Ou directement :
bash scripts/add-org.sh 3 2        # Ajoute Org3 avec 2 peers
bash scripts/add-peer.sh 1 3       # Ajoute peer3 à Org1
bash scripts/add-orderer.sh 4      # Ajoute orderer4 au cluster Raft
```

Le backend **auto-détecte** les nouvelles organisations grâce aux fichiers `connection-org*.json`. Après ajout d'une org, un simple appel `POST /api/organizations/reload` recharge la config.

---

## 📡 API Backend

| Méthode | Route | Description |
|---|---|---|
| `GET` | `/api/health` | Santé du serveur |
| `GET` | `/api/organizations` | Liste des organisations |
| `POST` | `/api/organizations/reload` | Recharger les orgs dynamiquement |
| `GET` | `/api/dashboard/stats` | Statistiques du dashboard |
| `GET` | `/api/accounts` | Tous les comptes |
| `POST` | `/api/accounts/create` | Créer un compte |
| `PUT` | `/api/accounts/:id` | Modifier un compte |
| `PATCH` | `/api/accounts/:id/toggle-block` | Bloquer/débloquer |
| `GET` | `/api/users` | Tous les utilisateurs |
| `POST` | `/api/users/create` | Créer un utilisateur |
| `PUT` | `/api/users/:id` | Modifier un utilisateur |
| `PATCH` | `/api/users/:id/toggle` | Activer/désactiver |
| `GET` | `/api/transactions` | Historique des transactions |
| `POST` | `/api/transfer` | Transférer des tokens |
| `POST` | `/api/mint` | Créer des tokens (mint) |

---

## 🛠️ Technologies

| Composant | Technologies |
|---|---|
| **Frontend** | React 19, TypeScript, Vite, TailwindCSS 4, Recharts, ApexCharts |
| **Backend** | Node.js, Express.js, Fabric SDK 2.2 |
| **Blockchain** | Hyperledger Fabric 2.5, Go Chaincode, Raft Consensus |
| **Infrastructure** | Docker, nginx, CouchDB, Fabric CA (TLS + Root + Intermediate) |
| **CI/Docker** | Multi-stage builds, docker-compose |

---

## 📄 Licence

Ce projet est sous licence [MIT](LICENSE.md).
