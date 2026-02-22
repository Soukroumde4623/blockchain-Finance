#!/bin/bash
# ============================================================================
# ADD-ORDERER.SH — Ajouter un nouvel orderer au cluster Raft
# Usage: bash scripts/add-orderer.sh <ORDERER_NUMBER>
# Exemple: bash scripts/add-orderer.sh 4    → Ajoute orderer4 au cluster
# ============================================================================
set -e

ORDERER_NUM=$1

if [ -z "$ORDERER_NUM" ]; then
  echo "Usage: $0 <ORDERER_NUMBER>"
  echo "  Exemple: $0 4  → Ajoute orderer4 au cluster Raft"
  exit 1
fi

if [ "$ORDERER_NUM" -le 3 ]; then
  echo "Erreur: Les orderers 1-3 existent déjà. Utilisez un numéro >= 4."
  exit 1
fi

BASE_DIR="${PWD}/hyperledger-fabric-network"
export FABRIC_CFG_PATH="${BASE_DIR}/config"

ADMIN_PASSWORD="adminpw"
ORDERER_PASSWORD="ordererpw"

# Calculer les ports du nouvel orderer
# Convention: orderer1=7071, orderer2=7072, orderer3=7073, orderer4=7074, ...
ORDERER_PORT=$((7070 + ORDERER_NUM))
ADMIN_PORT=$((9450 + ORDERER_NUM))
OPS_PORT=$((8440 + ORDERER_NUM))
CLUSTER_PORT=$((9070 + ORDERER_NUM))
ORDERER_HOST="orderer${ORDERER_NUM}.finance.com"

echo "============================================================"
echo "  AJOUT DE orderer${ORDERER_NUM} AU CLUSTER RAFT"
echo "  - Port orderer: ${ORDERER_PORT}"
echo "  - Port admin: ${ADMIN_PORT}"
echo "  - Port cluster: ${CLUSTER_PORT}"
echo "  - Port ops: ${OPS_PORT}"
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
# ÉTAPE 2: Enregistrer & Enrôler le nouvel orderer
# =========================================
echo ""
echo ">>> Étape 2/6: Enregistrement de osn${ORDERER_NUM}..."
cd ${BASE_DIR}/fabric-ca-client

# Orderer MSP
${BASE_DIR}/bin/fabric-ca-client register -d --id.name osn${ORDERER_NUM} --id.secret ${ORDERER_PASSWORD} \
  --id.type orderer -u https://int-ca.finance.com:7057 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir crypto/satCert-ca-int/intadmin/msp || echo "osn${ORDERER_NUM} déjà enregistré"

mkdir -p ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/{msp,tls}
${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://osn${ORDERER_NUM}:${ORDERER_PASSWORD}@int-ca.finance.com:7057 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/msp

# Orderer TLS
${BASE_DIR}/bin/fabric-ca-client register -d --id.name osn${ORDERER_NUM}tls --id.secret ${ORDERER_PASSWORD} \
  --id.type orderer -u https://tls-ca.finance.com:7054 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir crypto/tls-ca/tlsadmin/msp || echo "osn${ORDERER_NUM}tls déjà enregistré"

${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://osn${ORDERER_NUM}tls:${ORDERER_PASSWORD}@tls-ca.finance.com:7054 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls --csr.hosts "${ORDERER_HOST}" \
  --mspdir ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/tls

# Renommer clés
KEY_FILE=$(find ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/tls/keystore/ -type f | head -n 1)
[ -n "$KEY_FILE" ] && mv "$KEY_FILE" ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/tls/keystore/key.pem

KEY_FILE=$(find ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/msp/keystore/ -type f | head -n 1)
[ -n "$KEY_FILE" ] && mv "$KEY_FILE" ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/msp/keystore/key.pem

# Copier admin certs
mkdir -p ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/msp/{admincerts,tlscacerts}
cp ${BASE_DIR}/crypto/Orderer/orderer1/msp/admincerts/admin-cert.pem \
   ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/msp/admincerts/admin-cert.pem
cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
   ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/msp/tlscacerts/tls-ca-cert.pem

mkdir -p ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/tls/tlscacerts
cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
   ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/tls/tlscacerts/tls-ca-cert.pem

echo "✓ orderer${ORDERER_NUM} enrôlé."

# =========================================
# ÉTAPE 3: Générer orderer.yaml
# =========================================
echo ""
echo ">>> Étape 3/6: Génération orderer.yaml..."

cat > ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/orderer.yaml <<EOF
General:
  ListenAddress: 0.0.0.0
  ListenPort: ${ORDERER_PORT}
  TLS:
    Enabled: true
    Certificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
    PrivateKey: /etc/hyperledger/orderer/tls/keystore/key.pem
    RootCAs:
      - /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
  Cluster:
    ClientCertificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
    ClientPrivateKey: /etc/hyperledger/orderer/tls/keystore/key.pem
    RootCAs:
      - /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
    ListenAddress: 0.0.0.0
    ListenPort: ${CLUSTER_PORT}
    ServerCertificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
    ServerPrivateKey: /etc/hyperledger/orderer/tls/keystore/key.pem
  LocalMSPDir: /etc/hyperledger/orderer/msp
  LocalMSPID: OrdererMSP
  BootstrapMethod: none
  BCCSP:
    Default: SW
    SW:
      Hash: SHA2
      Security: 256
FileLedger:
  Location: /var/hyperledger/production/orderer
Admin:
  ListenAddress: 0.0.0.0:${ADMIN_PORT}
  TLS:
    Enabled: true
    Certificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
    PrivateKey: /etc/hyperledger/orderer/tls/keystore/key.pem
    RootCAs:
      - /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
    ClientAuthRequired: true
    ClientRootCAs:
      - /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
Operations:
  ListenAddress: 0.0.0.0:${OPS_PORT}
  TLS:
    Enabled: false
Consensus:
  WALDir: /var/hyperledger/production/orderer/etcdraft/wal
  SnapDir: /var/hyperledger/production/orderer/etcdraft/snapshot
ChannelParticipation:
  Enabled: true
EOF

echo "✓ orderer.yaml généré."

# =========================================
# ÉTAPE 4: Démarrer le conteneur
# =========================================
echo ""
echo ">>> Étape 4/6: Démarrage du conteneur orderer${ORDERER_NUM}..."

# Ajouter hostname
if ! grep -q "${ORDERER_HOST}" /etc/hosts; then
  echo "127.0.0.1 ${ORDERER_HOST}" | sudo tee -a /etc/hosts > /dev/null
fi

# Créer ledger dir
mkdir -p ${BASE_DIR}/ledger/orderer${ORDERER_NUM}

COMPOSE_FILE="${BASE_DIR}/docker-compose-orderer${ORDERER_NUM}.yaml"
cat > ${COMPOSE_FILE} <<COMPOSE
version: "3.9"
networks:
  fabric_network:
    external: true
services:
  orderer${ORDERER_NUM}:
    image: hyperledger/fabric-orderer:2.5
    container_name: orderer${ORDERER_NUM}
    hostname: ${ORDERER_HOST}
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=${ORDERER_PORT}
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem]
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_GENERAL_CLUSTER_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem]
      - ORDERER_GENERAL_CLUSTER_LISTENPORT=${CLUSTER_PORT}
      - ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_CLUSTER_SERVERCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_CLUSTER_SERVERPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_GENERAL_BOOTSTRAPMETHOD=none
      - ORDERER_ADMIN_LISTENADDRESS=0.0.0.0:${ADMIN_PORT}
      - ORDERER_ADMIN_TLS_ENABLED=true
      - ORDERER_ADMIN_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_ADMIN_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_ADMIN_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem]
      - ORDERER_ADMIN_TLS_CLIENTAUTHREQUIRED=true
      - ORDERER_ADMIN_TLS_CLIENTROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem]
      - ORDERER_CHANNELPARTICIPATION_ENABLED=true
      - ORDERER_OPERATIONS_LISTENADDRESS=0.0.0.0:${OPS_PORT}
    volumes:
      - ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}:/etc/hyperledger/orderer
      - ${BASE_DIR}/ledger/orderer${ORDERER_NUM}:/var/hyperledger/production
    ports:
      - "${ORDERER_PORT}:${ORDERER_PORT}"
      - "${ADMIN_PORT}:${ADMIN_PORT}"
      - "${OPS_PORT}:${OPS_PORT}"
      - "${CLUSTER_PORT}:${CLUSTER_PORT}"
    networks:
      - fabric_network
    command: orderer
    restart: unless-stopped
COMPOSE

docker-compose -f ${COMPOSE_FILE} up -d
echo "✓ orderer${ORDERER_NUM} démarré."
sleep 15

# =========================================
# ÉTAPE 5: Ajouter le consenter au canal via config update
# =========================================
echo ""
echo ">>> Étape 5/6: Ajout du consenter orderer${ORDERER_NUM} au canal..."

# Récupérer le cert TLS du nouvel orderer (en base64)
TLS_CERT_B64=$(base64 -w0 ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/tls/signcerts/cert.pem)

# Fetch config actuelle
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  peer channel fetch config /tmp/orderer_config_block.pb -o orderer1.finance.com:7071 \
  --ordererTLSHostnameOverride orderer1.finance.com \
  -c tokenchannel --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem

# Décoder
docker exec fabric-cli configtxlator proto_decode --input /tmp/orderer_config_block.pb --type common.Block --output /tmp/orderer_config_block.json
docker exec fabric-cli sh -c "cat /tmp/orderer_config_block.json | jq '.data.data[0].payload.data.config' > /tmp/orderer_config.json"

# Ajouter le nouveau consenter
docker exec fabric-cli sh -c "jq '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters += [{\"client_tls_cert\":\"${TLS_CERT_B64}\",\"host\":\"${ORDERER_HOST}\",\"port\":${CLUSTER_PORT},\"server_tls_cert\":\"${TLS_CERT_B64}\"}]' /tmp/orderer_config.json > /tmp/orderer_modified_config.json"

# Aussi ajouter l'endpoint orderer dans les Endpoints
docker exec fabric-cli sh -c "jq '.channel_group.groups.Orderer.values.Endpoints.value.addresses += [\"${ORDERER_HOST}:${ORDERER_PORT}\"]' /tmp/orderer_modified_config.json > /tmp/orderer_modified_config2.json && mv /tmp/orderer_modified_config2.json /tmp/orderer_modified_config.json"

# Calculer le delta
docker exec fabric-cli configtxlator proto_encode --input /tmp/orderer_config.json --type common.Config --output /tmp/orderer_config.pb
docker exec fabric-cli configtxlator proto_encode --input /tmp/orderer_modified_config.json --type common.Config --output /tmp/orderer_modified_config.pb
docker exec fabric-cli configtxlator compute_update --channel_id tokenchannel --original /tmp/orderer_config.pb --updated /tmp/orderer_modified_config.pb --output /tmp/orderer_update.pb

# Envelopper
docker exec fabric-cli sh -c "echo '{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"tokenchannel\",\"type\":2}},\"data\":{\"config_update\":\"'$(docker exec fabric-cli base64 -w0 /tmp/orderer_update.pb)'\"}}}' | jq . > /tmp/orderer_update_envelope.json"
docker exec fabric-cli configtxlator proto_encode --input /tmp/orderer_update_envelope.json --type common.Envelope --output /tmp/orderer_update_envelope.pb

# Signer par Org1
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  peer channel signconfigtx -f /tmp/orderer_update_envelope.pb

# Soumettre par Org2
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org2MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg2/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org2.finance.com:7053 \
  peer channel update -f /tmp/orderer_update_envelope.pb -c tokenchannel \
  -o orderer1.finance.com:7071 --ordererTLSHostnameOverride orderer1.finance.com \
  --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem

echo "✓ Consenter orderer${ORDERER_NUM} ajouté au canal."

# =========================================
# ÉTAPE 6: Joindre le canal via osnadmin
# =========================================
echo ""
echo ">>> Étape 6/6: Joindre orderer${ORDERER_NUM} au canal via osnadmin..."

# Fetch le dernier bloc config
docker exec fabric-cli env \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  peer channel fetch config /tmp/latest_config.block -o orderer1.finance.com:7071 \
  --ordererTLSHostnameOverride orderer1.finance.com \
  -c tokenchannel --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem

docker cp fabric-cli:/tmp/latest_config.block /tmp/latest_config.block

# Utiliser osnadmin pour joindre le canal
${BASE_DIR}/bin/osnadmin channel join --channelID tokenchannel \
  --config-block /tmp/latest_config.block \
  -o ${ORDERER_HOST}:${ADMIN_PORT} \
  --ca-file ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --client-cert ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/tls/signcerts/cert.pem \
  --client-key ${BASE_DIR}/crypto/Orderer/orderer${ORDERER_NUM}/tls/keystore/key.pem

echo "✓ orderer${ORDERER_NUM} a rejoint le canal tokenchannel."

# Mettre à jour les connection profiles existants pour inclure le nouvel orderer
echo ""
echo ">>> Mise à jour des connection profiles..."
for conn_file in ${PWD}/backend/config/connection-org*.json; do
  if [ -f "$conn_file" ]; then
    TMP=$(mktemp)
    jq --arg name "orderer${ORDERER_NUM}" \
       --arg url "grpcs://localhost:${ORDERER_PORT}" \
       --arg tls "../hyperledger-fabric-network/crypto/Orderer/orderer${ORDERER_NUM}/tls/tlscacerts/tls-ca-cert.pem" \
       --arg host "${ORDERER_HOST}" \
       '.orderers[$name] = {"url": $url, "tlsCACerts": {"path": $tls}, "grpcOptions": {"ssl-target-name-override": $host}}' \
       "$conn_file" > "$TMP" && mv "$TMP" "$conn_file"
    echo "  ✓ $(basename $conn_file) mis à jour"
  fi
done

# Arrêter les CAs
cd ${BASE_DIR}
docker-compose -f docker-compose-ca.yaml down 2>/dev/null || true

echo ""
echo "============================================================"
echo "  ✅ orderer${ORDERER_NUM} AJOUTÉ AVEC SUCCÈS"
echo "  - Port: ${ORDERER_PORT}"
echo "  - Admin: ${ADMIN_PORT}"
echo "  - Cluster: ${CLUSTER_PORT}"
echo "  - Canal: tokenchannel (consenter + member)"
echo ""
echo "  ⚠ Redémarrer le backend pour prendre en compte"
echo "============================================================"
