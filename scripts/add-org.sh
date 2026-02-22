#!/bin/bash
# ============================================================================
# ADD-ORG.SH — Ajouter une nouvelle organisation au réseau Fabric existant
# Usage: bash scripts/add-org.sh <ORG_NUMBER> [PEER_COUNT]
# Exemple: bash scripts/add-org.sh 3 2    → Crée Org3 avec 2 peers
# ============================================================================
set -e

ORG_NUM=$1
PEER_COUNT=${2:-2}

if [ -z "$ORG_NUM" ]; then
  echo "Usage: $0 <ORG_NUMBER> [PEER_COUNT]"
  echo "  Exemple: $0 3 2  → Crée Org3MSP avec 2 peers"
  exit 1
fi

if [ "$ORG_NUM" -le 2 ]; then
  echo "Erreur: Les organisations 1 et 2 existent déjà. Utilisez un numéro >= 3."
  exit 1
fi

BASE_DIR="${PWD}/hyperledger-fabric-network"
export FABRIC_CFG_PATH="${BASE_DIR}/config"

# Mots de passe (les mêmes que setup.sh)
ADMIN_PASSWORD="adminpw"
PEER_PASSWORD="peerpw"

# Calculer les ports automatiquement
# Convention: Org1 peers sur 7051-7052, Org2 sur 7053-7054, Org3 sur 7055-7056, etc.
BASE_PEER_PORT=$((7049 + (ORG_NUM - 1) * 2))
BASE_COUCHDB_PORT=$((5982 + (ORG_NUM - 1) * 2))
# IPs Docker: orderers 172.18.0.2-4, peers org1 172.18.0.5-6, org2 172.18.0.7-8, cli 172.18.0.9, couchdb 172.18.0.10-13
# Nouvelle org: on saute au-delà du dernier IP utilisé
BASE_IP_PEER=$((4 + (ORG_NUM) * 2 - 1))     # peers
BASE_IP_COUCH=$((9 + (ORG_NUM) * 2 + 1))    # couchdb

echo "============================================================"
echo "  AJOUT DE Org${ORG_NUM} AU RÉSEAU FABRIC"
echo "  - ${PEER_COUNT} peers"
echo "  - Ports peers: $((BASE_PEER_PORT+1))-$((BASE_PEER_PORT+PEER_COUNT))"
echo "  - CouchDB ports: $((BASE_COUCHDB_PORT+1))-$((BASE_COUCHDB_PORT+PEER_COUNT))"
echo "============================================================"

# =========================================
# ÉTAPE 1: Démarrer les CAs
# =========================================
echo ""
echo ">>> Étape 1/8: Démarrage des CAs..."
cd ${BASE_DIR}
docker-compose -f docker-compose-ca.yaml up -d 2>/dev/null || true
sleep 15

# =========================================
# ÉTAPE 2: Enregistrer & Enrôler l'admin et peers
# =========================================
echo ""
echo ">>> Étape 2/8: Enregistrement de adminOrg${ORG_NUM} et peers..."
cd ${BASE_DIR}/fabric-ca-client

# Admin MSP
${BASE_DIR}/bin/fabric-ca-client register -d --id.name adminOrg${ORG_NUM} --id.secret ${ADMIN_PASSWORD} \
  --id.type admin -u https://int-ca.finance.com:7057 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir crypto/satCert-ca-int/intadmin/msp || echo "adminOrg${ORG_NUM} déjà enregistré"

mkdir -p ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/{msp,tls}
${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://adminOrg${ORG_NUM}:${ADMIN_PASSWORD}@int-ca.finance.com:7057 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp

# Admin TLS
${BASE_DIR}/bin/fabric-ca-client register -d --id.name adminOrg${ORG_NUM}tls --id.secret ${ADMIN_PASSWORD} \
  --id.type admin -u https://tls-ca.finance.com:7054 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir crypto/tls-ca/tlsadmin/msp || echo "adminOrg${ORG_NUM}tls déjà enregistré"

${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://adminOrg${ORG_NUM}tls:${ADMIN_PASSWORD}@tls-ca.finance.com:7054 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls --csr.hosts "admin-org${ORG_NUM}.finance.com" \
  --mspdir ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/tls

# Admin admincerts
mkdir -p ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp/admincerts
cp ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp/signcerts/cert.pem \
   ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp/admincerts/admin-cert.pem

# Peers
for peer in $(seq 1 $PEER_COUNT); do
  PEER_PORT=$((BASE_PEER_PORT + peer))
  PEER_HOST="peer${peer}-org${ORG_NUM}.finance.com"
  
  echo "  Registering peer${peer}Org${ORG_NUM}..."
  
  # Peer MSP
  ${BASE_DIR}/bin/fabric-ca-client register -d --id.name peer${peer}Org${ORG_NUM} --id.secret ${PEER_PASSWORD} \
    --id.type peer -u https://int-ca.finance.com:7057 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --mspdir crypto/satCert-ca-int/intadmin/msp || echo "peer${peer}Org${ORG_NUM} déjà enregistré"

  mkdir -p ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/{msp,tls}
  ${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://peer${peer}Org${ORG_NUM}:${PEER_PASSWORD}@int-ca.finance.com:7057 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --mspdir ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/msp

  # Peer TLS
  ${BASE_DIR}/bin/fabric-ca-client register -d --id.name peer${peer}Org${ORG_NUM}tls --id.secret ${PEER_PASSWORD} \
    --id.type peer -u https://tls-ca.finance.com:7054 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --mspdir crypto/tls-ca/tlsadmin/msp || echo "peer${peer}Org${ORG_NUM}tls déjà enregistré"

  ${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://peer${peer}Org${ORG_NUM}tls:${PEER_PASSWORD}@tls-ca.finance.com:7054 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --enrollment.profile tls --csr.hosts "${PEER_HOST}" \
    --mspdir ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/tls

  # Renommer clés TLS
  KEY_FILE=$(find ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/tls/keystore/ -type f | head -n 1)
  if [ -n "$KEY_FILE" ]; then
    mv "$KEY_FILE" ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/tls/keystore/key.pem
  fi

  # Renommer clés MSP
  KEY_FILE=$(find ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/msp/keystore/ -type f | head -n 1)
  if [ -n "$KEY_FILE" ]; then
    mv "$KEY_FILE" ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/msp/keystore/key.pem
  fi

  # Copier TLS CA cert et admincerts
  mkdir -p ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/tls/tlscacerts
  cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
     ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/tls/tlscacerts/tls-ca-cert.pem
  
  mkdir -p ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/msp/{admincerts,tlscacerts}
  cp ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp/signcerts/cert.pem \
     ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/msp/admincerts/admin-cert.pem
  cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
     ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/msp/tlscacerts/tls-ca-cert.pem

  echo "  ✓ peer${peer}Org${ORG_NUM} enrôlé (port ${PEER_PORT})"
done

echo "✓ Tous les certificats générés."

# =========================================
# ÉTAPE 3: Créer le MSP d'organisation
# =========================================
echo ""
echo ">>> Étape 3/8: Création du MSP Org${ORG_NUM}MSP..."

mkdir -p ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/{admincerts,cacerts,intermediatecerts,tlscacerts}
cp ${BASE_DIR}/fabric-ca-server/ca-cert.pem ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/cacerts/root-ca-cert.pem
cp ${BASE_DIR}/fabric-ca-int-server/ca-cert.pem ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/intermediatecerts/int-ca-cert.pem
cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/tlscacerts/tls-ca-cert.pem
cp ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp/signcerts/cert.pem \
   ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/admincerts/admin-cert.pem

echo "✓ MSP Org${ORG_NUM}MSP créé."

# =========================================
# ÉTAPE 4: Générer core.yaml pour chaque peer
# =========================================
echo ""
echo ">>> Étape 4/8: Génération core.yaml..."

for peer in $(seq 1 $PEER_COUNT); do
  PEER_PORT=$((BASE_PEER_PORT + peer))
  PEER_HOST="peer${peer}-org${ORG_NUM}.finance.com"
  COUCHDB_HOST="couchdb-peer${peer}-org${ORG_NUM}.finance.com"
  
  # Bootstrap vers l'autre peer de la même org
  if [ $peer -eq 1 ] && [ $PEER_COUNT -ge 2 ]; then
    BOOT_PEER="peer2-org${ORG_NUM}.finance.com:$((BASE_PEER_PORT + 2))"
  else
    BOOT_PEER="peer1-org${ORG_NUM}.finance.com:$((BASE_PEER_PORT + 1))"
  fi

  cat > ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/core.yaml <<EOF
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
  echo "  ✓ core.yaml pour peer${peer}Org${ORG_NUM}"
done

# =========================================
# ÉTAPE 5: Générer docker-compose-org${ORG_NUM}.yaml
# =========================================
echo ""
echo ">>> Étape 5/8: Génération docker-compose-org${ORG_NUM}.yaml..."

COMPOSE_FILE="${BASE_DIR}/docker-compose-org${ORG_NUM}.yaml"
cat > ${COMPOSE_FILE} <<COMPOSE_HEADER
version: "3.9"
networks:
  fabric_network:
    external: true
services:
COMPOSE_HEADER

for peer in $(seq 1 $PEER_COUNT); do
  PEER_PORT=$((BASE_PEER_PORT + peer))
  CHAINCODE_PORT=$((8000 + PEER_PORT))
  COUCHDB_PORT=$((BASE_COUCHDB_PORT + peer))
  PEER_HOST="peer${peer}-org${ORG_NUM}.finance.com"
  COUCHDB_HOST="couchdb-peer${peer}-org${ORG_NUM}.finance.com"
  
  if [ $peer -eq 1 ] && [ $PEER_COUNT -ge 2 ]; then
    BOOT="peer2-org${ORG_NUM}.finance.com:$((BASE_PEER_PORT + 2))"
  else
    BOOT="peer1-org${ORG_NUM}.finance.com:$((BASE_PEER_PORT + 1))"
  fi

  # CouchDB
  cat >> ${COMPOSE_FILE} <<EOF
  couchdb-peer${peer}-org${ORG_NUM}:
    image: couchdb:3.4
    container_name: couchdb-peer${peer}-org${ORG_NUM}
    hostname: ${COUCHDB_HOST}
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "${COUCHDB_PORT}:5984"
    networks:
      - fabric_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5984/"]
      interval: 30s
      timeout: 10s
      retries: 5
    restart: unless-stopped
EOF

  # Peer
  cat >> ${COMPOSE_FILE} <<EOF
  peer${peer}-org${ORG_NUM}:
    image: hyperledger/fabric-peer:2.5
    container_name: peer${peer}-org${ORG_NUM}
    hostname: ${PEER_HOST}
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_ID=${PEER_HOST}
      - CORE_PEER_ADDRESS=${PEER_HOST}:${PEER_PORT}
      - CORE_PEER_LISTENADDRESS=0.0.0.0:${PEER_PORT}
      - CORE_PEER_CHAINCODEADDRESS=${PEER_HOST}:${CHAINCODE_PORT}
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:${CHAINCODE_PORT}
      - CORE_PEER_GOSSIP_BOOTSTRAP=${BOOT}
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
      - ${BASE_DIR}/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}:/etc/hyperledger/peer
      - ${BASE_DIR}/ledger/peer${peer}org${ORG_NUM}:/var/hyperledger/production
      - /var/run/docker.sock:/host/var/run/docker.sock
    ports:
      - "${PEER_PORT}:${PEER_PORT}"
      - "${CHAINCODE_PORT}:${CHAINCODE_PORT}"
    networks:
      - fabric_network
    depends_on:
      - couchdb-peer${peer}-org${ORG_NUM}
    command: peer node start
    restart: unless-stopped
EOF
done

echo "✓ ${COMPOSE_FILE} généré."

# =========================================
# ÉTAPE 6: Démarrer les conteneurs
# =========================================
echo ""
echo ">>> Étape 6/8: Démarrage des conteneurs Org${ORG_NUM}..."

# Ajouter les hostnames dans /etc/hosts
for peer in $(seq 1 $PEER_COUNT); do
  PEER_HOST="peer${peer}-org${ORG_NUM}.finance.com"
  COUCHDB_HOST="couchdb-peer${peer}-org${ORG_NUM}.finance.com"
  for h in $PEER_HOST $COUCHDB_HOST; do
    if ! grep -q "$h" /etc/hosts; then
      echo "127.0.0.1 $h" | sudo tee -a /etc/hosts > /dev/null
    fi
  done
done

# Créer ledger dirs
for peer in $(seq 1 $PEER_COUNT); do
  mkdir -p ${BASE_DIR}/ledger/peer${peer}org${ORG_NUM}
done

docker-compose -f ${COMPOSE_FILE} up -d
echo "✓ Conteneurs Org${ORG_NUM} démarrés."
sleep 30

# =========================================
# ÉTAPE 7: Ajouter Org au canal via config update
# =========================================
echo ""
echo ">>> Étape 7/8: Ajout de Org${ORG_NUM}MSP au canal tokenchannel..."

ORDERER1_PORT=7071
PEER1_ORG1_PORT=7051

# Générer le JSON de définition de l'org
ANCHOR_PEERS_JSON="["
for peer in $(seq 1 $PEER_COUNT); do
  PEER_PORT=$((BASE_PEER_PORT + peer))
  if [ $peer -gt 1 ]; then ANCHOR_PEERS_JSON+=","; fi
  ANCHOR_PEERS_JSON+="{\"host\":\"peer${peer}-org${ORG_NUM}.finance.com\",\"port\":${PEER_PORT}}"
done
ANCHOR_PEERS_JSON+="]"

cat > /tmp/org${ORG_NUM}_definition.json <<ORGDEF
{
  "name": "Org${ORG_NUM}MSP",
  "msp_type": 0,
  "root_certs": ["$(base64 -w0 ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/intermediatecerts/int-ca-cert.pem)"],
  "intermediate_certs": [],
  "admins": ["$(base64 -w0 ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/admincerts/admin-cert.pem)"],
  "tls_root_certs": ["$(base64 -w0 ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/tlscacerts/tls-ca-cert.pem)"],
  "tls_intermediate_certs": [],
  "organizational_unit_identifiers": [],
  "fabric_node_ous": {
    "enable": true,
    "client_ou_identifier": {"certificate": "$(base64 -w0 ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/intermediatecerts/int-ca-cert.pem)", "organizational_unit_identifier": "client"},
    "peer_ou_identifier": {"certificate": "$(base64 -w0 ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/intermediatecerts/int-ca-cert.pem)", "organizational_unit_identifier": "peer"},
    "admin_ou_identifier": {"certificate": "$(base64 -w0 ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/intermediatecerts/int-ca-cert.pem)", "organizational_unit_identifier": "admin"},
    "orderer_ou_identifier": {"certificate": "$(base64 -w0 ${BASE_DIR}/crypto/Org${ORG_NUM}MSP/msp/intermediatecerts/int-ca-cert.pem)", "organizational_unit_identifier": "orderer"}
  }
}
ORGDEF

# Copier dans CLI
docker cp /tmp/org${ORG_NUM}_definition.json fabric-cli:/tmp/org${ORG_NUM}_definition.json

# Monter les certificats admin de la nouvelle org dans CLI
docker cp ${BASE_DIR}/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp fabric-cli:/etc/hyperledger/adminOrg${ORG_NUM}/msp

# Récupérer la config actuelle du canal
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  peer channel fetch config /tmp/config_block.pb -o orderer1.finance.com:${ORDERER1_PORT} \
  --ordererTLSHostnameOverride orderer1.finance.com \
  -c tokenchannel --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem

# Décoder en JSON
docker exec fabric-cli configtxlator proto_decode --input /tmp/config_block.pb --type common.Block --output /tmp/config_block.json
docker exec fabric-cli sh -c "cat /tmp/config_block.json | jq '.data.data[0].payload.data.config' > /tmp/config.json"

# Ajouter la nouvelle org
docker exec fabric-cli sh -c "jq -s '.[0] * {\"channel_group\":{\"groups\":{\"Application\":{\"groups\":{\"Org${ORG_NUM}MSP\":{\"groups\":{},\"mod_policy\":\"Admins\",\"policies\":{\"Admins\":{\"mod_policy\":\"Admins\",\"policy\":{\"type\":1,\"value\":{\"identities\":[{\"principal\":{\"msp_identifier\":\"Org${ORG_NUM}MSP\",\"role\":\"ADMIN\"},\"principal_classification\":\"ROLE\"}],\"rule\":{\"n_out_of\":{\"n\":1,\"rules\":[{\"signed_by\":0}]}}}},\"version\":\"0\"},\"Endorsement\":{\"mod_policy\":\"Admins\",\"policy\":{\"type\":1,\"value\":{\"identities\":[{\"principal\":{\"msp_identifier\":\"Org${ORG_NUM}MSP\",\"role\":\"MEMBER\"},\"principal_classification\":\"ROLE\"}],\"rule\":{\"n_out_of\":{\"n\":1,\"rules\":[{\"signed_by\":0}]}}}},\"version\":\"0\"},\"Readers\":{\"mod_policy\":\"Admins\",\"policy\":{\"type\":1,\"value\":{\"identities\":[{\"principal\":{\"msp_identifier\":\"Org${ORG_NUM}MSP\",\"role\":\"MEMBER\"},\"principal_classification\":\"ROLE\"}],\"rule\":{\"n_out_of\":{\"n\":1,\"rules\":[{\"signed_by\":0}]}}}},\"version\":\"0\"},\"Writers\":{\"mod_policy\":\"Admins\",\"policy\":{\"type\":1,\"value\":{\"identities\":[{\"principal\":{\"msp_identifier\":\"Org${ORG_NUM}MSP\",\"role\":\"MEMBER\"},\"principal_classification\":\"ROLE\"}],\"rule\":{\"n_out_of\":{\"n\":1,\"rules\":[{\"signed_by\":0}]}}}},\"version\":\"0\"}},\"values\":{\"MSP\":{\"mod_policy\":\"Admins\",\"value\":{\"config\":$(cat /tmp/org${ORG_NUM}_definition.json)}}},\"version\":\"0\"}}}}}}' /tmp/config.json > /tmp/modified_config.json"

# Calculer le delta
docker exec fabric-cli configtxlator proto_encode --input /tmp/config.json --type common.Config --output /tmp/config.pb
docker exec fabric-cli configtxlator proto_encode --input /tmp/modified_config.json --type common.Config --output /tmp/modified_config.pb
docker exec fabric-cli configtxlator compute_update --channel_id tokenchannel --original /tmp/config.pb --updated /tmp/modified_config.pb --output /tmp/org${ORG_NUM}_update.pb

# Envelopper dans une transaction
docker exec fabric-cli sh -c "echo '{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"tokenchannel\",\"type\":2}},\"data\":{\"config_update\":\"'$(docker exec fabric-cli base64 -w0 /tmp/org${ORG_NUM}_update.pb)'\"}}}' | jq . > /tmp/org${ORG_NUM}_update_in_envelope.json"
docker exec fabric-cli configtxlator proto_encode --input /tmp/org${ORG_NUM}_update_in_envelope.json --type common.Envelope --output /tmp/org${ORG_NUM}_update_in_envelope.pb

# Signer par Org1
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  peer channel signconfigtx -f /tmp/org${ORG_NUM}_update_in_envelope.pb

# Soumettre par Org2 (MAJORITY = 2 signatures sur 2 orgs)
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org2MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg2/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org2.finance.com:7053 \
  peer channel update -f /tmp/org${ORG_NUM}_update_in_envelope.pb -c tokenchannel \
  -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com \
  --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem

echo "✓ Org${ORG_NUM}MSP ajoutée au canal tokenchannel."

# =========================================
# ÉTAPE 8: Joindre les peers et installer le chaincode
# =========================================
echo ""
echo ">>> Étape 8/8: Joindre les peers au canal et installer le chaincode..."

# Fetch le bloc du canal
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${ORG_NUM}/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  peer channel fetch 0 /tmp/tokenchannel.block -o orderer1.finance.com:${ORDERER1_PORT} \
  --ordererTLSHostnameOverride orderer1.finance.com \
  -c tokenchannel --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem

# Joindre chaque peer
for peer in $(seq 1 $PEER_COUNT); do
  PEER_PORT=$((BASE_PEER_PORT + peer))
  docker exec fabric-cli env \
    CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP \
    CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${ORG_NUM}/msp \
    CORE_PEER_TLS_ENABLED=true \
    CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
    CORE_PEER_ADDRESS=peer${peer}-org${ORG_NUM}.finance.com:${PEER_PORT} \
    peer channel join -b /tmp/tokenchannel.block
  echo "  ✓ peer${peer}-org${ORG_NUM} a rejoint tokenchannel"
done

# Installer le chaincode sur les nouveaux peers
for peer in $(seq 1 $PEER_COUNT); do
  PEER_PORT=$((BASE_PEER_PORT + peer))
  docker exec fabric-cli env \
    CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP \
    CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${ORG_NUM}/msp \
    CORE_PEER_TLS_ENABLED=true \
    CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
    CORE_PEER_ADDRESS=peer${peer}-org${ORG_NUM}.finance.com:${PEER_PORT} \
    peer lifecycle chaincode install /etc/hyperledger/chaincode/token/token.tar.gz
  echo "  ✓ Chaincode installé sur peer${peer}-org${ORG_NUM}"
done

# Approuver le chaincode pour la nouvelle org
CURRENT_SEQ=$(docker exec fabric-cli peer lifecycle chaincode querycommitted --channelID tokenchannel --name token 2>&1 | grep -oP 'Sequence: \K[0-9]+')
CURRENT_VER=$(docker exec fabric-cli peer lifecycle chaincode querycommitted --channelID tokenchannel --name token 2>&1 | grep -oP 'Version: \K[0-9.]+')

PACKAGE_ID=$(docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${ORG_NUM}/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org${ORG_NUM}.finance.com:$((BASE_PEER_PORT + 1)) \
  peer lifecycle chaincode queryinstalled 2>&1 | grep "Label: token" | tail -1 | awk -F'Package ID: ' '{print $2}' | cut -d',' -f1)

echo "  Package ID: ${PACKAGE_ID}"
echo "  Current version: ${CURRENT_VER}, sequence: ${CURRENT_SEQ}"

docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${ORG_NUM}/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org${ORG_NUM}.finance.com:$((BASE_PEER_PORT + 1)) \
  peer lifecycle chaincode approveformyorg -o orderer1.finance.com:${ORDERER1_PORT} \
  --ordererTLSHostnameOverride orderer1.finance.com \
  --channelID tokenchannel --name token --version ${CURRENT_VER} \
  --package-id ${PACKAGE_ID} --sequence ${CURRENT_SEQ} \
  --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem

echo "  ✓ Chaincode approuvé par Org${ORG_NUM}MSP"

# =========================================
# ÉTAPE 9: Générer le connection profile + mettre à jour le backend
# =========================================
echo ""
echo ">>> Génération du profil de connexion pour Org${ORG_NUM}..."

BACKEND_CONFIG="${PWD}/backend/config"
mkdir -p ${BACKEND_CONFIG}

# Générer les entrées peers JSON
PEERS_JSON=""
PEER_NAMES="["
for peer in $(seq 1 $PEER_COUNT); do
  PEER_PORT=$((BASE_PEER_PORT + peer))
  PEER_HOST="peer${peer}-org${ORG_NUM}.finance.com"
  if [ $peer -gt 1 ]; then PEERS_JSON+=","; PEER_NAMES+=","; fi
  PEER_NAMES+="\"peer${peer}-org${ORG_NUM}\""
  PEERS_JSON+="
    \"peer${peer}-org${ORG_NUM}\": {
      \"url\": \"grpcs://localhost:${PEER_PORT}\",
      \"tlsCACerts\": { \"path\": \"../hyperledger-fabric-network/crypto/Org${ORG_NUM}/peer${peer}Org${ORG_NUM}/tls/tlscacerts/tls-ca-cert.pem\" },
      \"grpcOptions\": { \"ssl-target-name-override\": \"${PEER_HOST}\", \"hostnameOverride\": \"${PEER_HOST}\" }
    }"
done
PEER_NAMES+="]"

cat > ${BACKEND_CONFIG}/connection-org${ORG_NUM}.json <<CONNEOF
{
  "name": "fabric-network-org${ORG_NUM}",
  "version": "1.0.0",
  "client": {
    "organization": "Org${ORG_NUM}",
    "connection": { "timeout": { "peer": { "endorser": 300 }, "orderer": 300 } }
  },
  "organizations": {
    "Org${ORG_NUM}": {
      "mspid": "Org${ORG_NUM}MSP",
      "peers": ${PEER_NAMES},
      "certificateAuthorities": [],
      "adminPrivateKey": { "path": "../hyperledger-fabric-network/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp/keystore/key.pem" },
      "signedCert": { "path": "../hyperledger-fabric-network/crypto/Org${ORG_NUM}/adminOrg${ORG_NUM}/msp/signcerts/cert.pem" }
    }
  },
  "peers": { ${PEERS_JSON} },
  "orderers": {
    "orderer1": { "url": "grpcs://localhost:7071", "tlsCACerts": { "path": "../hyperledger-fabric-network/crypto/Orderer/orderer1/tls/tlscacerts/tls-ca-cert.pem" }, "grpcOptions": { "ssl-target-name-override": "orderer1.finance.com" } },
    "orderer2": { "url": "grpcs://localhost:7072", "tlsCACerts": { "path": "../hyperledger-fabric-network/crypto/Orderer/orderer2/tls/tlscacerts/tls-ca-cert.pem" }, "grpcOptions": { "ssl-target-name-override": "orderer2.finance.com" } },
    "orderer3": { "url": "grpcs://localhost:7073", "tlsCACerts": { "path": "../hyperledger-fabric-network/crypto/Orderer/orderer3/tls/tlscacerts/tls-ca-cert.pem" }, "grpcOptions": { "ssl-target-name-override": "orderer3.finance.com" } }
  },
  "certificateAuthorities": {}
}
CONNEOF

echo "✓ Connection profile: ${BACKEND_CONFIG}/connection-org${ORG_NUM}.json"

# Arrêter les CAs (on n'en a plus besoin)
cd ${BASE_DIR}
docker-compose -f docker-compose-ca.yaml down 2>/dev/null || true

echo ""
echo "============================================================"
echo "  ✅ Org${ORG_NUM} AJOUTÉE AVEC SUCCÈS"
echo "  - ${PEER_COUNT} peers sur ports $((BASE_PEER_PORT+1))-$((BASE_PEER_PORT+PEER_COUNT))"
echo "  - Connection profile: backend/config/connection-org${ORG_NUM}.json"
echo ""
echo "  ⚠ IMPORTANT: Redémarrer le backend pour prendre en compte"
echo "  la nouvelle org. Le backend auto-détecte les connection-org*.json"
echo "============================================================"
