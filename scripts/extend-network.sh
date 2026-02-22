#!/bin/bash
# ============================================================================
# EXTEND-NETWORK.SH — Script interactif pour étendre le réseau Fabric
# Usage: bash scripts/extend-network.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     HYPERLEDGER FABRIC — EXTENSION DU RÉSEAU              ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  1) Ajouter une nouvelle organisation                     ║"
echo "║  2) Ajouter un peer à une organisation existante          ║"
echo "║  3) Ajouter un orderer au cluster Raft                    ║"
echo "║  4) Voir l'état actuel du réseau                          ║"
echo "║  5) Quitter                                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
read -p "Votre choix [1-5]: " CHOICE

case $CHOICE in
  1)
    echo ""
    read -p "Numéro de la nouvelle organisation (ex: 3): " ORG_NUM
    read -p "Nombre de peers (défaut: 2): " PEER_COUNT
    PEER_COUNT=${PEER_COUNT:-2}
    echo ""
    echo "→ Ajout de Org${ORG_NUM} avec ${PEER_COUNT} peers..."
    bash "${SCRIPT_DIR}/add-org.sh" $ORG_NUM $PEER_COUNT
    ;;
  2)
    echo ""
    read -p "Numéro de l'organisation (ex: 1): " ORG_NUM
    read -p "Numéro du nouveau peer (ex: 3): " PEER_NUM
    echo ""
    echo "→ Ajout de peer${PEER_NUM} à Org${ORG_NUM}..."
    bash "${SCRIPT_DIR}/add-peer.sh" $ORG_NUM $PEER_NUM
    ;;
  3)
    echo ""
    read -p "Numéro du nouvel orderer (ex: 4): " ORDERER_NUM
    echo ""
    echo "→ Ajout de orderer${ORDERER_NUM} au cluster..."
    bash "${SCRIPT_DIR}/add-orderer.sh" $ORDERER_NUM
    ;;
  4)
    echo ""
    echo "=== État actuel du réseau ==="
    echo ""
    echo "--- Conteneurs Fabric en cours d'exécution ---"
    docker ps --filter "network=fabric_network" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | sort
    echo ""
    echo "--- Organisations sur le canal tokenchannel ---"
    docker exec fabric-cli env \
      CORE_PEER_LOCALMSPID=Org1MSP \
      CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
      CORE_PEER_TLS_ENABLED=true \
      CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
      peer channel fetch config /tmp/status_config.pb -o orderer1.finance.com:7071 \
      --ordererTLSHostnameOverride orderer1.finance.com \
      -c tokenchannel --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem 2>/dev/null

    docker exec fabric-cli configtxlator proto_decode --input /tmp/status_config.pb --type common.Block 2>/dev/null | \
      jq -r '.data.data[0].payload.data.config.channel_group.groups.Application.groups | keys[]' 2>/dev/null | \
      while read org; do echo "  ✓ $org"; done

    echo ""
    echo "--- Orderers (consenters) ---"
    docker exec fabric-cli configtxlator proto_decode --input /tmp/status_config.pb --type common.Block 2>/dev/null | \
      jq -r '.data.data[0].payload.data.config.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters[] | "\(.host):\(.port)"' 2>/dev/null | \
      while read osn; do echo "  ✓ $osn"; done

    echo ""
    echo "--- Connection profiles backend ---"
    ls -la ${PWD}/backend/config/connection-org*.json 2>/dev/null || echo "  Aucun profil trouvé"
    echo ""
    ;;
  5)
    echo "Au revoir!"
    exit 0
    ;;
  *)
    echo "Choix invalide. Relancez le script."
    exit 1
    ;;
esac

echo ""
echo "⚠ N'oubliez pas de redémarrer le backend:"
echo "   cd backend && node server.js"
