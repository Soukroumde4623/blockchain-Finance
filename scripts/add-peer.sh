#!/bin/bash
# ============================================================================
# ADD-PEER.SH — Ajouter un nouveau peer à une organisation existante
# Usage: bash scripts/add-peer.sh <ORG_NUMBER> <NEW_PEER_NUMBER>
# Exemple: bash scripts/add-peer.sh 1 3    → Ajoute peer3 à Org1
# ============================================================================
set -e

ORG_NUM=$1
PEER_NUM=$2

if [ -z "$ORG_NUM" ] || [ -z "$PEER_NUM" ]; then
  echo "Usage: $0 <ORG_NUMBER> <NEW_PEER_NUMBER>"
  echo "  Exemple: $0 1 3  → Ajoute peer3 à Org1"
  exit 1
fi

BASE_DIR="${PWD}/hyperledger-fabric-network"
export FABRIC_CFG_PATH="${BASE_DIR}/config"

ADMIN_PASSWORD="adminpw"
PEER_PASSWORD="peerpw"

# Calculer le port du nouveau peer
# On calcule le dernier port peer utilisé par l'org et on ajoute 1
BASE_PEER_PORT=$((7049 + (ORG_NUM - 1) * 2))
PEER_PORT=$((BASE_PEER_PORT + PEER_NUM))
CHAINCODE_PORT=$((8000 + PEER_PORT))

# CouchDB: calculer un port libre
BASE_COUCHDB_PORT=$((5982 + (ORG_NUM - 1) * 2))
COUCHDB_PORT=$((BASE_COUCHDB_PORT + PEER_NUM))

PEER_HOST="peer${PEER_NUM}-org${ORG_NUM}.finance.com"
COUCHDB_HOST="couchdb-peer${PEER_NUM}-org${ORG_NUM}.finance.com"
BOOT_PEER="peer1-org${ORG_NUM}.finance.com:$((BASE_PEER_PORT + 1))"

echo "============================================================"
echo "  AJOUT DE peer${PEER_NUM} À Org${ORG_NUM}"
echo "  - Port peer: ${PEER_PORT}"
echo "  - Port CouchDB: ${COUCHDB_PORT}"
echo "  - Bootstrap: ${BOOT_PEER}"
echo "============================================================"

# =========================================
# ÉTAPE 1: Démarrer les CAs
# =========================================
echo ""
echo ">>> Étape 1/6: Démarrage des CAs..."
cd ${BASE_DIR}
docker-compose -f docker-compose-ca.yaml up -d 2>/dev/null || true
sleep 15

# =========================================
# ÉTAPE 2: Enregistrer & Enrôler le nouveau peer
# =========================================
echo ""
echo ">>> Étape 2/6: Enregistrement de peer${PEER_NUM}Org${ORG_NUM}..."
cd ${BASE_DIR}/fabric-ca-client

# Peer MSP
${BASE_DIR}/bin/fabric-ca-client register -d --id.name peer${PEER_NUM}Org${ORG_NUM} --id.secret ${PEER_PASSWORD} \
  --id.type peer -u https://int-ca.finance.com:7057 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir crypto/satCert-ca-int/intadmin/msp || echo "peer${PEER_NUM}Org${ORG_NUM} déjà enregistré"

mkdir -p ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/{msp,tls}
${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://peer${PEER_NUM}Org${ORG_NUM}:${PEER_PASSWORD}@int-ca.finance.com:7057 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/msp

# Peer TLS
${BASE_DIR}/bin/fabric-ca-client register -d --id.name peer${PEER_NUM}Org${ORG_NUM}tls --id.secret ${PEER_PASSWORD} \
  --id.type peer -u https://tls-ca.finance.com:7054 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir crypto/tls-ca/tlsadmin/msp || echo "peer${PEER_NUM}Org${ORG_NUM}tls déjà enregistré"

${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://peer${PEER_NUM}Org${ORG_NUM}tls:${PEER_PASSWORD}@tls-ca.finance.com:7054 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls --csr.hosts "${PEER_HOST}" \
  --mspdir ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/tls

# Renommer clés
KEY_FILE=$(find ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/tls/keystore/ -type f | head -n 1)
[ -n "$KEY_FILE" ] && mv "$KEY_FILE" ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/tls/keystore/key.pem

KEY_FILE=$(find ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/msp/keystore/ -type f | head -n 1)
[ -n "$KEY_FILE" ] && mv "$KEY_FILE" ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/msp/keystore/key.pem

# Copier TLS CA cert et admincerts
mkdir -p ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/tls/tlscacerts
cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
   ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/tls/tlscacerts/tls-ca-cert.pem

mkdir -p ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/msp/{admincerts,tlscacerts}
cp ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp/signcerts/cert.pem \
   ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/msp/admincerts/admin-cert.pem
cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
   ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/msp/tlscacerts/tls-ca-cert.pem

echo "✓ peer${PEER_NUM}Org${ORG_NUM} enrôlé."

# =========================================
# ÉTAPE 3: Générer core.yaml
# =========================================
echo ""
echo ">>> Étape 3/6: Génération core.yaml..."

cat > ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/core.yaml <<EOF
logging:
  level: info
peer:
  id: ${PEER_HOST}
  networkId: finance-network
  listenAddress: 0.0.0.0:${PEER_PORT}
  address: ${PEER_HOST}:${PEER_PORT}
  localMspId: Org${ORG_NUM}MSP
  mspConfigPath: /etc/hyperledger/peer/msp
  BCCSP:
    Default: SW
    SW:
      Hash: SHA2
      Security: 256
  gossip:
    bootstrap: ${BOOT_PEER}
    externalEndpoint: ${PEER_HOST}:${PEER_PORT}
    useLeaderElection: true
    orgLeader: false
  tls:
    enabled: true
    cert:
      file: /etc/hyperledger/peer/tls/signcerts/cert.pem
    key:
      file: /etc/hyperledger/peer/tls/keystore/key.pem
    rootcert:
      file: /etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
  chaincode:
    externalBuilders:
      - name: ccaas_builder
        path: /opt/hyperledger/ccaas_builder
vm:
  endpoint: unix:///host/var/run/docker.sock
  docker:
    hostConfig:
      NetworkMode: fabric_network
ledger:
  state:
    stateDatabase: CouchDB
    couchDBConfig:
      couchDBAddress: ${COUCHDB_HOST}:5984
      username: admin
      password: adminpw
EOF

echo "✓ core.yaml généré."

# =========================================
# ÉTAPE 4: Démarrer le conteneur
# =========================================
echo ""
echo ">>> Étape 4/6: Démarrage des conteneurs..."

# Ajouter hostnames
for h in ${PEER_HOST} ${COUCHDB_HOST}; do
  if ! grep -q "$h" /etc/hosts; then
    echo "127.0.0.1 $h" | sudo tee -a /etc/hosts > /dev/null
  fi
done

# Créer ledger dir
mkdir -p ${BASE_DIR}/ledger/peer${PEER_NUM}org${ORG_NUM}

# Générer un mini docker-compose
COMPOSE_FILE="${BASE_DIR}/docker-compose-peer${PEER_NUM}-org${ORG_NUM}.yaml"
cat > ${COMPOSE_FILE} <<COMPOSE
version: "3.9"
networks:
  fabric_network:
    external: true
services:
  couchdb-peer${PEER_NUM}-org${ORG_NUM}:
    image: couchdb:3.4
    container_name: couchdb-peer${PEER_NUM}-org${ORG_NUM}
    hostname: ${COUCHDB_HOST}
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "${COUCHDB_PORT}:5984"
    networks:
      - fabric_network
    restart: unless-stopped
  peer${PEER_NUM}-org${ORG_NUM}:
    image: hyperledger/fabric-peer:2.5
    container_name: peer${PEER_NUM}-org${ORG_NUM}
    hostname: ${PEER_HOST}
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_ID=${PEER_HOST}
      - CORE_PEER_ADDRESS=${PEER_HOST}:${PEER_PORT}
      - CORE_PEER_LISTENADDRESS=0.0.0.0:${PEER_PORT}
      - CORE_PEER_CHAINCODEADDRESS=${PEER_HOST}:${CHAINCODE_PORT}
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:${CHAINCODE_PORT}
      - CORE_PEER_GOSSIP_BOOTSTRAP=${BOOT_PEER}
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=${PEER_HOST}:${PEER_PORT}
      - CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_network
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=${COUCHDB_HOST}:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
    volumes:
      - ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}:/etc/hyperledger/peer
      - ${BASE_DIR}/ledger/peer${PEER_NUM}org${ORG_NUM}:/var/hyperledger/production
      - /var/run/docker.sock:/host/var/run/docker.sock
    ports:
      - "${PEER_PORT}:${PEER_PORT}"
      - "${CHAINCODE_PORT}:${CHAINCODE_PORT}"
    networks:
      - fabric_network
    depends_on:
      - couchdb-peer${PEER_NUM}-org${ORG_NUM}
    command: peer node start
    restart: unless-stopped
COMPOSE

docker-compose -f ${COMPOSE_FILE} up -d
echo "✓ Conteneurs démarrés."
sleep 20

# =========================================
# ÉTAPE 5: Joindre le canal
# =========================================
echo ""
echo ">>> Étape 5/6: Joindre peer${PEER_NUM} à tokenchannel..."

# Fetch le genesis block
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${ORG_NUM}/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  peer channel fetch 0 /tmp/tokenchannel_peer${PEER_NUM}org${ORG_NUM}.block \
  -o orderer1.finance.com:7071 --ordererTLSHostnameOverride orderer1.finance.com \
  -c tokenchannel --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem

# Copier les certs dans le CLI pour accéder au nouveau peer
docker cp ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp fabric-cli:/etc/hyperledger/adminOrg${ORG_NUM}/msp

# Joindre le canal
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${ORG_NUM}/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=${PEER_HOST}:${PEER_PORT} \
  peer channel join -b /tmp/tokenchannel_peer${PEER_NUM}org${ORG_NUM}.block

echo "✓ peer${PEER_NUM}-org${ORG_NUM} a rejoint tokenchannel."

# =========================================
# ÉTAPE 6: Installer le chaincode
# =========================================
echo ""
echo ">>> Étape 6/6: Installation du chaincode..."

docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${ORG_NUM}/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=${PEER_HOST}:${PEER_PORT} \
  peer lifecycle chaincode install /etc/hyperledger/chaincode/token/token.tar.gz

echo "✓ Chaincode installé."

# Mettre à jour le connection profile
echo ""
echo ">>> Mise à jour du connection profile de Org${ORG_NUM}..."

CONN_FILE="${PWD}/backend/config/connection-org${ORG_NUM}.json"
if [ -f "$CONN_FILE" ]; then
  # Ajouter le nouveau peer dans le JSON
  TMP=$(mktemp)
  jq --arg name "peer${PEER_NUM}-org${ORG_NUM}" \
     --arg url "grpcs://localhost:${PEER_PORT}" \
     --arg tls "../hyperledger-fabric-network/crypto/Org${ORG_NUM}/peer${PEER_NUM}Org${ORG_NUM}/tls/tlscacerts/tls-ca-cert.pem" \
     --arg host "${PEER_HOST}" \
     '.peers[$name] = {"url": $url, "tlsCACerts": {"path": $tls}, "grpcOptions": {"ssl-target-name-override": $host, "hostnameOverride": $host}} | .organizations["Org"+("'${ORG_NUM}'" | tostring)].peers += [$name]' \
     "$CONN_FILE" > "$TMP" && mv "$TMP" "$CONN_FILE"
  echo "✓ Connection profile mis à jour."
fi

# Arrêter les CAs
cd ${BASE_DIR}
docker-compose -f docker-compose-ca.yaml down 2>/dev/null || true

echo ""
echo "============================================================"
echo "  ✅ peer${PEER_NUM}-org${ORG_NUM} AJOUTÉ AVEC SUCCÈS"
echo "  - Port: ${PEER_PORT}"
echo "  - CouchDB: ${COUCHDB_PORT}"
echo "  - Canal: tokenchannel"
echo "  - Chaincode: installé"
echo ""
echo "  ⚠ Redémarrer le backend pour prendre en compte le nouveau peer"
echo "============================================================"
