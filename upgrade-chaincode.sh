#!/bin/bash
# Script de mise à jour du chaincode token (version 2.0, séquence 2)
set -e

BASE_DIR="${PWD}/hyperledger-fabric-network"
export FABRIC_CFG_PATH="${BASE_DIR}/config"

ORDERER1_PORT=7071
PEER1_ORG1_PORT=7051
PEER2_ORG1_PORT=7052
PEER1_ORG2_PORT=7053
PEER2_ORG2_PORT=7054

echo "============================================"
echo "  UPGRADE CHAINCODE token → v2.0 (seq 2)"
echo "============================================"

# 1. Rebuild l'image Docker du chaincode
echo ""
echo ">>> Étape 1/7 : Rebuild de l'image Docker..."
cd ${BASE_DIR}/chaincode/token

# Écrire un Dockerfile à jour
cat > Dockerfile <<'EOF'
FROM golang:1.23
WORKDIR /go/src/token
COPY . .
RUN go mod tidy
RUN go get github.com/hyperledger/fabric-chaincode-go/shim
RUN go get github.com/hyperledger/fabric-contract-api-go/contractapi@v1.2.2
RUN CGO_ENABLED=0 GOOS=linux go build -o token
CMD ["./token"]
EOF

docker build -t token-chaincode:latest --no-cache .
echo "✓ Image Docker reconstruite."

# 2. Redémarrer le conteneur chaincode avec la nouvelle image
echo ""
echo ">>> Étape 2/7 : Redémarrage du conteneur chaincode..."
cd ${BASE_DIR}
docker-compose -f ${BASE_DIR}/docker-compose-chaincode.yaml down
docker-compose -f ${BASE_DIR}/docker-compose-chaincode.yaml up -d
echo "✓ Conteneur chaincode redémarré."
sleep 10

# 3. Re-packager le chaincode (CCAAS)
echo ""
echo ">>> Étape 3/7 : Re-packaging du chaincode..."

# Recréer le package tar.gz pour CCAAS
mkdir -p /tmp/chaincode-pkg
cd /tmp/chaincode-pkg
rm -rf *

# connection.json pour CCAAS
cat > connection.json <<'CONN_EOF'
{
  "address": "token-chaincode:9999",
  "dial_timeout": "10s",
  "tls_required": false
}
CONN_EOF

# metadata.json
cat > metadata.json <<'META_EOF'
{
  "type": "ccaas",
  "label": "token"
}
META_EOF

# Créer le tar du code
tar czf code.tar.gz connection.json

# Créer le package final
tar czf ${BASE_DIR}/chaincode/token/token.tar.gz metadata.json code.tar.gz
echo "✓ Package chaincode recréé."

# Copier le package dans le conteneur CLI
docker cp ${BASE_DIR}/chaincode/token/token.tar.gz fabric-cli:/etc/hyperledger/chaincode/token/token.tar.gz
echo "✓ Package copié dans le conteneur CLI."

# 4. Installer le nouveau package sur tous les peers
echo ""
echo ">>> Étape 4/7 : Installation sur tous les peers..."
for org in 1 2; do
  for peer in 1 2; do
    eval PEER_PORT=\$PEER${peer}_ORG${org}_PORT
    echo "  Installing on peer${peer}-org${org} (port ${PEER_PORT})..."
    docker exec fabric-cli env \
      FABRIC_LOGGING_SPEC=INFO \
      CORE_PEER_LOCALMSPID=Org${org}MSP \
      CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${org}/msp \
      CORE_PEER_TLS_ENABLED=true \
      CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
      CORE_PEER_ADDRESS=peer${peer}-org${org}.finance.com:${PEER_PORT} \
      peer lifecycle chaincode install /etc/hyperledger/chaincode/token/token.tar.gz
    echo "  ✓ Installé sur peer${peer}-org${org}."
  done
done

# 5. Récupérer le nouveau PACKAGE_ID
echo ""
echo ">>> Étape 5/7 : Récupération du Package ID..."
INSTALLED_OUTPUT=$(docker exec fabric-cli env \
  FABRIC_LOGGING_SPEC=INFO \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org1.finance.com:${PEER1_ORG1_PORT} \
  peer lifecycle chaincode queryinstalled)
echo "$INSTALLED_OUTPUT"

# Prendre le dernier Package ID avec label "token"
CHAINCODE_ID=$(echo "$INSTALLED_OUTPUT" | grep "Label: token" | tail -1 | awk -F'Package ID: ' '{print $2}' | cut -d',' -f1)
if [ -z "$CHAINCODE_ID" ]; then
  echo "Erreur : impossible de récupérer le nouveau Package ID."
  exit 1
fi
echo "✓ Nouveau Package ID : $CHAINCODE_ID"

# Mettre à jour le CHAINCODE_ID dans docker-compose-chaincode.yaml
cd ${BASE_DIR}
docker-compose -f docker-compose-chaincode.yaml down
sed -i "s|CHAINCODE_ID=.*|CHAINCODE_ID=${CHAINCODE_ID}|" docker-compose-chaincode.yaml
docker-compose -f docker-compose-chaincode.yaml up -d
echo "✓ Conteneur chaincode redémarré avec le bon Package ID."
sleep 10

# 6. Approuver pour chaque org avec séquence 2
echo ""
echo ">>> Étape 6/7 : Approbation pour chaque organisation (sequence 2)..."
for org in 1 2; do
  eval PEER_PORT=\$PEER1_ORG${org}_PORT
  echo "  Approving for Org${org}MSP..."
  docker exec fabric-cli env \
    FABRIC_LOGGING_SPEC=INFO \
    CORE_PEER_LOCALMSPID=Org${org}MSP \
    CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${org}/msp \
    CORE_PEER_TLS_ENABLED=true \
    CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
    CORE_PEER_ADDRESS=peer1-org${org}.finance.com:${PEER_PORT} \
    peer lifecycle chaincode approveformyorg -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com \
    --channelID tokenchannel --name token --version 2.0 --package-id ${CHAINCODE_ID} --sequence 2 \
    --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
  echo "  ✓ Approuvé pour Org${org}MSP."
  sleep 5
done

# 7. Commit du chaincode avec séquence 2
echo ""
echo ">>> Étape 7/7 : Commit du chaincode (version 2.0, sequence 2)..."
docker exec fabric-cli env \
  FABRIC_LOGGING_SPEC=INFO \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org1.finance.com:${PEER1_ORG1_PORT} \
  peer lifecycle chaincode commit -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com \
  --channelID tokenchannel --name token --version 2.0 --sequence 2 \
  --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem \
  --peerAddresses peer1-org1.finance.com:${PEER1_ORG1_PORT} --tlsRootCertFiles /etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  --peerAddresses peer1-org2.finance.com:${PEER1_ORG2_PORT} --tlsRootCertFiles /etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem

echo ""
echo "✓ Commit réussi !"

# Vérification finale
echo ""
echo ">>> Vérification finale..."
docker exec fabric-cli peer lifecycle chaincode querycommitted --channelID tokenchannel --name token

echo ""
echo "============================================"
echo "  ✅ CHAINCODE UPGRADED TO v2.0 (seq 2)"
echo "============================================"
