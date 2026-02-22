#!/bin/bash
# Déploiement d'un réseau Hyperledger Fabric de production avec 3 orderers, 2 organisations (2 peers chacune), et chaincode de token en utilisant Docker Compose
# Arrêter le script en cas d'erreur
set -e
# Vérifier que l'utilisateur a les permissions nécessaires
if [ ! -w "$HOME" ]; then
  echo "Erreur : l'utilisateur $(whoami) n'a pas les permissions d'écriture dans $HOME."
  echo "Veuillez exécuter le script avec sudo ou corriger les permissions avec 'sudo chown -R $(whoami):$(whoami) $HOME'."
  exit 1
fi
# Vérifier si l'utilisateur peut exécuter chown sans sudo
if ! touch /tmp/testfile && sudo chown $(whoami):$(whoami) /tmp/testfile 2>/dev/null; then
  echo "Erreur : l'utilisateur $(whoami) n'a pas les permissions nécessaires pour modifier les propriétaires des fichiers."
  echo "Veuillez exécuter le script avec sudo."
  exit 1
fi
rm -f /tmp/testfile
# Définir le répertoire de base
BASE_DIR="hyperledger-fabric-network"
FABRIC_CFG_PATH="${BASE_DIR}/config"
export FABRIC_CFG_PATH
# Vérifier que BASE_DIR existe
if ! mkdir -p "${BASE_DIR}"; then
  echo "Erreur : impossible de créer le répertoire ${BASE_DIR}."
  exit 1
fi
# Correction des permissions initiales
echo "Correction des permissions initiales..."
sudo chown -R $(whoami):$(whoami) ${BASE_DIR} || true
sudo chmod -R u+rw ${BASE_DIR} || true
# Variables d'environnement pour secrets (sans caractères spéciaux)
: ${ADMIN_PASSWORD:="adminpw"}
: ${SATCERT_PASSWORD:="satcertpw"}
: ${INT_PASSWORD:="intpw"}
: ${ORDERER_PASSWORD:="ordererpw"}
: ${PEER_PASSWORD:="peerpw"}
# Domaines FQDN pour production
TLS_CA_HOST="tls-ca.finance.com"
ROOT_CA_HOST="root-ca.finance.com"
INT_CA_HOST="int-ca.finance.com"
ORDERER1_HOST="orderer1.finance.com"
ORDERER2_HOST="orderer2.finance.com"
ORDERER3_HOST="orderer3.finance.com"
PEER1_ORG1_HOST="peer1-org1.finance.com"
PEER2_ORG1_HOST="peer2-org1.finance.com"
PEER1_ORG2_HOST="peer1-org2.finance.com"
PEER2_ORG2_HOST="peer2-org2.finance.com"
COUCHDB_HOST="couchdb.finance.com"
# Ports corrigés pour éviter conflits (orderers à partir de 7071)
ORDERER1_PORT=7071
ORDERER2_PORT=7072
ORDERER3_PORT=7073
ORDERER1_ADMIN_PORT=9451
ORDERER2_ADMIN_PORT=9452
ORDERER3_ADMIN_PORT=9453
ORDERER1_OPERATIONS_PORT=8441
ORDERER2_OPERATIONS_PORT=8442
ORDERER3_OPERATIONS_PORT=8443
PEER1_ORG1_PORT=7051
PEER2_ORG1_PORT=7052
PEER1_ORG2_PORT=7053
PEER2_ORG2_PORT=7054
# Téléchargement des binaires Fabric 2.5.13 si nécessaire
echo "Vérification des binaires Fabric dans ${BASE_DIR}/bin..."
mkdir -p ${BASE_DIR}/bin
if [ ! -f "${BASE_DIR}/bin/configtxgen" ]; then
  echo "Binaire configtxgen manquant. Téléchargement des binaires Hyperledger Fabric 2.5.13..."
  curl -sSL https://github.com/hyperledger/fabric/releases/download/v2.5.13/hyperledger-fabric-linux-amd64-2.5.13.tar.gz -o ${BASE_DIR}/hyperledger-fabric-2.5.13.tar.gz
  if [ $? -ne 0 ]; then
    echo "Erreur : échec du téléchargement des binaires Fabric 2.5.13."
    exit 1
  fi
  tar -xzf ${BASE_DIR}/hyperledger-fabric-2.5.13.tar.gz -C ${BASE_DIR}/
  mv ${BASE_DIR}/bin/* ${BASE_DIR}/bin/ || true
  rm -rf ${BASE_DIR}/hyperledger-fabric-2.5.13.tar.gz ${BASE_DIR}/config
  chmod +x ${BASE_DIR}/bin/*
  echo "Binaires Fabric 2.5.13 téléchargés et installés."
fi
# Téléchargement des binaires Fabric CA 1.5.11 si nécessaire (séparé pour versions 2.x)
if [ ! -f "${BASE_DIR}/bin/fabric-ca-client" ]; then
  echo "Binaire fabric-ca-client manquant. Téléchargement des binaires Hyperledger Fabric CA 1.5.11..."
  curl -sSL https://github.com/hyperledger/fabric-ca/releases/download/v1.5.11/hyperledger-fabric-ca-linux-amd64-1.5.11.tar.gz -o ${BASE_DIR}/hyperledger-fabric-ca-1.5.11.tar.gz
  if [ $? -ne 0 ]; then
    echo "Erreur : échec du téléchargement des binaires Fabric CA 1.5.11."
    exit 1
  fi
  tar -xzf ${BASE_DIR}/hyperledger-fabric-ca-1.5.11.tar.gz -C ${BASE_DIR}/
  mv ${BASE_DIR}/bin/* ${BASE_DIR}/bin/ || true
  rm -rf ${BASE_DIR}/hyperledger-fabric-ca-1.5.11.tar.gz
  chmod +x ${BASE_DIR}/bin/*
  echo "Binaires Fabric CA 1.5.11 téléchargés et installés."
fi
# Vérifier la présence des binaires Fabric
for binary in configtxgen configtxlator discover fabric-ca-client fabric-ca-server orderer osnadmin peer; do
  if [ ! -f "${BASE_DIR}/bin/${binary}" ]; then
    echo "Erreur : Binaire ${binary} manquant dans ${BASE_DIR}/bin. Téléchargement échoué ou fichier corrompu."
    exit 1
  fi
done
echo "Tous les binaires Fabric sont présents."
# Créer la structure de répertoires
echo "Création de la structure de répertoires..."
mkdir -p ${BASE_DIR}/chaincode/token
mkdir -p ${BASE_DIR}/channel-artifacts
mkdir -p ${BASE_DIR}/config
mkdir -p ${BASE_DIR}/crypto/{intadmin,Orderer,Org1,Org2,rootadmin,tlsadmin,tls-ca-root-cert}
mkdir -p ${BASE_DIR}/crypto/Orderer/{orderer1,orderer2,orderer3}/{msp,tls}/{admincerts,cacerts,intermediatecerts,keystore,signcerts,tlscacerts,user}
mkdir -p ${BASE_DIR}/crypto/Org1/{adminOrg1,peer1Org1,peer2Org1}/{msp,tls}/{admincerts,cacerts,intermediatecerts,keystore,signcerts,tlscacerts,user}
mkdir -p ${BASE_DIR}/crypto/Org2/{adminOrg2,peer1Org2,peer2Org2}/{msp,tls}/{admincerts,cacerts,intermediatecerts,keystore,signcerts,tlscacerts,user}
mkdir -p ${BASE_DIR}/crypto/{rootadmin,tlsadmin}/{cacerts,keystore,signcerts,user}
mkdir -p ${BASE_DIR}/fabric-ca-client/msp/{cacerts,intadmin,rootadmin,tlsadmin,user}
mkdir -p ${BASE_DIR}/fabric-ca-client/crypto/tls-ca-root-cert
mkdir -p ${BASE_DIR}/fabric-ca-int-server/{msp,tls}/{cacerts,keystore,signcerts,user}
mkdir -p ${BASE_DIR}/fabric-ca-server/{msp,tls}/{cacerts,keystore,signcerts,user}
mkdir -p ${BASE_DIR}/fabric-ca-tls-server/{msp,tls}/{cacerts,keystore,signcerts,user}
mkdir -p ${BASE_DIR}/ledger/{orderer1,orderer2,orderer3}
mkdir -p ${BASE_DIR}/ledger/peer{1,2}org{1,2}
mkdir -p ${BASE_DIR}/ordererSAT_COM/{orderer1,orderer2,orderer3}
mkdir -p ${BASE_DIR}/peerSAT_COM
mkdir -p ${BASE_DIR}/scripts/channel-artifacts
mkdir -p ${BASE_DIR}/crypto/OrdererOrg/msp/{admincerts,cacerts,intermediatecerts,tlscacerts}
mkdir -p ${BASE_DIR}/crypto/Org1MSP/msp/{admincerts,cacerts,intermediatecerts,tlscacerts}
mkdir -p ${BASE_DIR}/crypto/Org2MSP/msp/{admincerts,cacerts,intermediatecerts,tlscacerts}
echo "Structure de répertoires créée."
# Installer les prérequis
echo "Installation des prérequis..."
sudo apt update
sudo apt install -y jq git curl nodejs npm golang-go docker.io docker-compose
echo "Prérequis installés."
# Vérifier que l'utilisateur est dans le groupe docker
if ! groups $(whoami) | grep -q docker; then
  echo "Ajout de l'utilisateur $(whoami) au groupe docker..."
  sudo usermod -aG docker $(whoami)
  echo "Utilisateur ajouté au groupe docker. Veuillez vous déconnecter et reconnecter, ou exécuter 'newgrp docker' avant de relancer le script."
  exit 1
fi
# Initialisation du module Go pour le chaincode
echo "Initialisation du module Go pour le chaincode..."
cd ${BASE_DIR}/chaincode/token
if [ ! -f "go.mod" ]; then
  go mod init token
else
  echo "go.mod existe déjà, initialisation ignorée."
fi
go get github.com/hyperledger/fabric-chaincode-go/shim
go get github.com/hyperledger/fabric-contract-api-go/contractapi@v1.2.2
go mod tidy
echo "Module Go initialisé."
# Créer le fichier token.go
echo "Création du fichier token.go..."
cat > ${BASE_DIR}/chaincode/token/token.go <<'EOF'
package main
import (
    "encoding/json"
    "fmt"
    "os"
    "github.com/hyperledger/fabric-chaincode-go/shim"
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)
type TokenContract struct {
    contractapi.Contract
}
type Token struct {
    Balance map[string]uint64 `json:"balance"`
    Allowance map[string]map[string]uint64 `json:"allowance"`
}
func (s *TokenContract) Init(ctx contractapi.TransactionContextInterface) error {
    token := Token{
        Balance: make(map[string]uint64),
        Allowance: make(map[string]map[string]uint64),
    }
    tokenBytes, _ := json.Marshal(token)
    return ctx.GetStub().PutState("token", tokenBytes)
}
func (s *TokenContract) Mint(ctx contractapi.TransactionContextInterface, to string, amount uint64) error {
    tokenBytes, err := ctx.GetStub().GetState("token")
    if err != nil {
        return fmt.Errorf("failed to read token: %v", err)
    }
    var token Token
    json.Unmarshal(tokenBytes, &token)
    token.Balance[to] += amount
    tokenBytes, _ = json.Marshal(token)
    return ctx.GetStub().PutState("token", tokenBytes)
}
func (s *TokenContract) Transfer(ctx contractapi.TransactionContextInterface, from string, to string, amount uint64) error {
    tokenBytes, err := ctx.GetStub().GetState("token")
    if err != nil {
        return fmt.Errorf("failed to read token: %v", err)
    }
    var token Token
    json.Unmarshal(tokenBytes, &token)
    if token.Balance[from] < amount {
        return fmt.Errorf("insufficient balance")
    }
    token.Balance[from] -= amount
    token.Balance[to] += amount
    tokenBytes, _ = json.Marshal(token)
    return ctx.GetStub().PutState("token", tokenBytes)
}
func (s *TokenContract) BalanceOf(ctx contractapi.TransactionContextInterface, account string) (uint64, error) {
    tokenBytes, err := ctx.GetStub().GetState("token")
    if err != nil {
        return 0, fmt.Errorf("failed to read token: %v", err)
    }
    var token Token
    json.Unmarshal(tokenBytes, &token)
    return token.Balance[account], nil
}
func (s *TokenContract) Approve(ctx contractapi.TransactionContextInterface, owner string, spender string, amount uint64) error {
    tokenBytes, err := ctx.GetStub().GetState("token")
    if err != nil {
        return fmt.Errorf("failed to read token: %v", err)
    }
    var token Token
    json.Unmarshal(tokenBytes, &token)
    if token.Allowance[owner] == nil {
        token.Allowance[owner] = make(map[string]uint64)
    }
    token.Allowance[owner][spender] = amount
    tokenBytes, _ = json.Marshal(token)
    return ctx.GetStub().PutState("token", tokenBytes)
}
func main() {
    cc, err := contractapi.NewChaincode(new(TokenContract))
    if err != nil {
        fmt.Printf("Error creating token chaincode: %s\n", err.Error())
        os.Exit(1)
    }
    server := &shim.ChaincodeServer{
        CCID: os.Getenv("CHAINCODE_ID"),
        Address: os.Getenv("CHAINCODE_SERVER_ADDRESS"),
        CC: cc,
        TLSProps: shim.TLSProperties{
            Disabled: true, // TLS disabled as per connection.json
        },
    }
    if err := server.Start(); err != nil {
        fmt.Printf("Error starting token chaincode server: %s\n", err.Error())
        os.Exit(1)
    }
}
EOF
echo "Fichier token.go créé : $(ls -l ${BASE_DIR}/chaincode/token/token.go)"
if [ ! -f "${BASE_DIR}/chaincode/token/token.go" ]; then
  echo "Erreur : token.go non généré dans ${BASE_DIR}/chaincode/token."
  exit 1
fi
# Créer les métadonnées du chaincode
echo "Création des métadonnées du chaincode..."
cat > ${BASE_DIR}/chaincode/token/metadata.json <<EOF
{
    "type": "ccaas",
    "label": "token"
}
EOF
echo "Métadonnées créées."
if [ ! -f "${BASE_DIR}/chaincode/token/metadata.json" ]; then
  echo "Erreur : metadata.json non généré dans ${BASE_DIR}/chaincode/token."
  exit 1
fi
# Créer connection.json pour CCAAS
cat > ${BASE_DIR}/chaincode/token/connection.json <<EOF
{
    "address": "token-chaincode:9999",
    "dial_timeout": "10s",
    "tls_required": false
}
EOF
if [ ! -f "${BASE_DIR}/chaincode/token/connection.json" ]; then
  echo "Erreur : connection.json non généré dans ${BASE_DIR}/chaincode/token."
  exit 1
fi
# Empaquetage du chaincode pour CCAAS
echo "Empaquetage du chaincode pour installation CCAAS..."
cd ${BASE_DIR}/chaincode/token
tar -czf code.tar.gz connection.json
tar -czf token.tar.gz code.tar.gz metadata.json
if [ ! -f "token.tar.gz" ]; then
  echo "Erreur : token.tar.gz non généré dans ${BASE_DIR}/chaincode/token."
  exit 1
fi
echo "Chaincode empaqueté avec succès."
# Compute CHAINCODE_ID
echo "Computing chaincode package ID..."
CHAINCODE_LABEL="token"
CHAINCODE_PACKAGE_FILE="${BASE_DIR}/chaincode/token/token.tar.gz"
CHAINCODE_HASH=$(sha256sum "${CHAINCODE_PACKAGE_FILE}" | awk '{print $1}')
CHAINCODE_ID="${CHAINCODE_LABEL}:${CHAINCODE_HASH}"
echo "Chaincode ID: ${CHAINCODE_ID}"
# Créer docker-compose-ca.yaml pour les CAs
cat > ${BASE_DIR}/docker-compose-ca.yaml <<EOF
version: '3.8'
networks:
  fabric_network:
    driver: bridge
services:
  fabric-tls-ca:
    image: hyperledger/fabric-ca:1.5
    hostname: tls-ca.finance.com
    environment:
      - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=tls-ca
      - FABRIC_CA_SERVER_PORT=7054
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_CSR_HOSTS=tls-ca.finance.com,fabric-tls-ca
    volumes:
      - ${BASE_DIR}/fabric-ca-tls-server:/etc/hyperledger/fabric-ca-server
      - ${BASE_DIR}/crypto/tls-ca-root-cert:/etc/hyperledger/fabric-ca-root-cert
    ports:
      - "7054:7054"
    networks:
      - fabric_network
    command: sh -c 'fabric-ca-server start -b tlsadmin:${ADMIN_PASSWORD}'
  fabric-root-ca:
    image: hyperledger/fabric-ca:1.5
    hostname: root-ca.finance.com
    environment:
      - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=satcertca
      - FABRIC_CA_SERVER_PORT=7055
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server/tls/cert.pem
      - FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server/tls/key.pem
      - FABRIC_CA_SERVER_CSR_HOSTS=root-ca.finance.com,fabric-root-ca
    volumes:
      - ${BASE_DIR}/fabric-ca-server:/etc/hyperledger/fabric-ca-server
      - ${BASE_DIR}/crypto/tls-ca-root-cert:/etc/hyperledger/fabric-ca-root-cert
    ports:
      - "7055:7055"
    networks:
      - fabric_network
    command: sh -c 'fabric-ca-server start -b rootadmin:${SATCERT_PASSWORD}'
    depends_on:
      - fabric-tls-ca
  fabric-intermediate-ca:
    image: hyperledger/fabric-ca:1.5
    hostname: int-ca.finance.com
    environment:
      - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=satCertcaint
      - FABRIC_CA_SERVER_PORT=7057
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server/tls/cert.pem
      - FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server/tls/key.pem
      - FABRIC_CA_SERVER_CSR_HOSTs=int-ca.finance.com,fabric-intermediate-ca
      - FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_URL=https://rootadmin:${SATCERT_PASSWORD}@root-ca.finance.com:7055
      - FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_CANAME=satcertca
      - FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=/etc/hyperledger/fabric-ca-root-cert/tls-ca-cert.pem
    volumes:
      - ${BASE_DIR}/fabric-ca-int-server:/etc/hyperledger/fabric-ca-server
      - ${BASE_DIR}/crypto/tls-ca-root-cert:/etc/hyperledger/fabric-ca-root-cert
    ports:
      - "7057:7057"
    networks:
      - fabric_network
    command: sh -c 'fabric-ca-server start -b intadmin:${INT_PASSWORD}'
    depends_on:
      - fabric-root-ca
EOF
echo "Fichier docker-compose-ca.yaml créé."
if [ ! -f "${BASE_DIR}/docker-compose-ca.yaml" ]; then
  echo "Erreur : docker-compose-ca.yaml non généré dans ${BASE_DIR}."
  exit 1
fi
# Vérifier les répertoires montés pour Docker
for dir in ${BASE_DIR}/crypto/Orderer/orderer{1,2,3} ${BASE_DIR}/crypto/Org{1,2} ${BASE_DIR}/fabric-ca-{server,int-server,tls-server} ${BASE_DIR}/ledger/orderer{1,2,3} ${BASE_DIR}/ledger/peer{1,2}org{1,2}; do
  if [ ! -d "$dir" ]; then
    echo "Erreur : le répertoire $dir n'existe pas."
    exit 1
  fi
done
# Démarrage séquentiel des conteneurs CA
echo "Démarrage séquentiel des conteneurs CA avec Docker Compose..."
cd ${BASE_DIR}
if [ ! -f "${BASE_DIR}/docker-compose-ca.yaml" ]; then
  echo "Erreur : fichier docker-compose-ca.yaml manquant dans ${BASE_DIR}."
  exit 1
fi
docker-compose -f ${BASE_DIR}/docker-compose-ca.yaml up -d fabric-tls-ca
echo "Conteneur TLS CA démarré."
sleep 60
# Copie du certificat TLS CA
echo "Copie du certificat TLS CA..."
TLS_CA_CONTAINER=$(docker ps -q -f name=fabric-tls-ca)
if [ -z "$TLS_CA_CONTAINER" ]; then
  echo "Erreur : Conteneur fabric-tls-ca non trouvé."
  exit 1
fi
docker cp ${TLS_CA_CONTAINER}:/etc/hyperledger/fabric-ca-server/ca-cert.pem ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem
docker cp ${TLS_CA_CONTAINER}:/etc/hyperledger/fabric-ca-server/ca-cert.pem ${BASE_DIR}/fabric-ca-client/crypto/tls-ca-root-cert/tls-ca-cert.pem
if [ ! -f "${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem" ]; then
  echo "Erreur : tls-ca-cert.pem non copié."
  exit 1
fi
echo "Certificat TLS CA copié."
# Démarrer Root CA
docker-compose -f ${BASE_DIR}/docker-compose-ca.yaml up -d fabric-root-ca
echo "Conteneur Root CA démarré."
sleep 60
# Enrôlement et configuration Root CA
echo "Enrôlement de l'admin du TLS CA..."
cd ${BASE_DIR}/fabric-ca-client
mkdir -p crypto/tls-ca/tlsadmin/msp
${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://tlsadmin:${ADMIN_PASSWORD}@tls-ca.finance.com:7054 \
  --tls.certfiles ${BASE_DIR}/fabric-ca-client/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls \
  --csr.hosts 'tls-ca.finance.com,fabric-tls-ca' \
  --mspdir crypto/tls-ca/tlsadmin/msp
echo "Admin TLS CA enrôlé."
echo "Enrôlement du Root CA avec TLS CA..."
mkdir -p crypto/tls-ca/rootadmin/msp
${BASE_DIR}/bin/fabric-ca-client register -d --id.name rootadmin --id.secret ${SATCERT_PASSWORD} \
  -u https://tls-ca.finance.com:7054 --tls.certfiles ${BASE_DIR}/fabric-ca-client/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir crypto/tls-ca/tlsadmin/msp || echo "--- Identité déjà enregistrée-----"
${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://rootadmin:${SATCERT_PASSWORD}@tls-ca.finance.com:7054 \
  --tls.certfiles ${BASE_DIR}/fabric-ca-client/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls --csr.hosts 'root-ca.finance.com,fabric-root-ca' \
  --mspdir ${BASE_DIR}/fabric-ca-server/tls
# Vérifier et renommer la clé privée si elle existe
KEY_FILE=$(find ${BASE_DIR}/fabric-ca-server/tls/keystore/ ${HOME}/.fabric-ca-client/msp/keystore/ -type f 2>/dev/null | head -n 1)
if [ -n "$KEY_FILE" ]; then
  mv "$KEY_FILE" ${BASE_DIR}/fabric-ca-server/tls/keystore/key.pem
  echo "Clé privée renommée pour Root CA depuis $KEY_FILE."
else
  echo "Erreur : aucune clé privée trouvée dans ${BASE_DIR}/fabric-ca-server/tls/keystore/ ou ${HOME}/.fabric-ca-client/msp/keystore/ pour Root CA."
  exit 1
fi
echo "Root CA enrôlé avec TLS CA."
# Copier les certificats pour le Root CA
echo "....................Copie des certificats pour le Root CA................."
cp ${BASE_DIR}/fabric-ca-server/tls/signcerts/cert.pem ${BASE_DIR}/fabric-ca-server/tls/cert.pem
cp ${BASE_DIR}/fabric-ca-server/tls/keystore/key.pem ${BASE_DIR}/fabric-ca-server/tls/key.pem
cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/fabric-ca-server/tls/tls-ca-cert.pem
echo "Certificats Root CA copiés."
# Vérifier la validité du certificat TLS du Root CA
if ! openssl verify -CAfile ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/fabric-ca-server/tls/cert.pem; then
  echo "Erreur : le certificat TLS du Root CA n'est pas signé par le TLS CA."
  exit 1
fi
# Redémarrage du Root CA
echo ".....................Redémarrage du conteneur Root CA................."
docker-compose -f ${BASE_DIR}/docker-compose-ca.yaml restart fabric-root-ca
sleep 60
# Enrôlement admin Root CA
echo ".................Enrôlement de l'admin du Root CA...................."
mkdir -p ${BASE_DIR}/fabric-ca-client/crypto/satCert-ca/rootadmin/msp
${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://rootadmin:${SATCERT_PASSWORD}@root-ca.finance.com:7055 \
  --tls.certfiles ${BASE_DIR}/fabric-ca-client/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --csr.hosts 'root-ca.finance.com,fabric-root-ca' \
  --mspdir crypto/satCert-ca/rootadmin/msp
echo "Admin Root CA enrôlé."
# Démarrer Intermediate CA
docker-compose -f ${BASE_DIR}/docker-compose-ca.yaml up -d fabric-intermediate-ca
echo "Conteneur Intermediate CA démarré."
sleep 60
# Enregistrement et enrôlement admin Intermediate CA
echo "..............Enregistrement de l'admin de l'Intermediate CA avec le TLS CA........."
${BASE_DIR}/bin/fabric-ca-client register -d --id.name intadmin --id.secret ${INT_PASSWORD} \
  -u https://tls-ca.finance.com:7054 --tls.certfiles ${BASE_DIR}/fabric-ca-client/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir crypto/tls-ca/tlsadmin/msp \
  --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"' || echo "...Identité déjà enregistrée........."
${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://intadmin:${INT_PASSWORD}@tls-ca.finance.com:7054 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls --csr.hosts 'int-ca.finance.com,fabric-intermediate-ca' \
  --mspdir ${BASE_DIR}/fabric-ca-int-server/tls
# Vérifier et renommer la clé privée si elle existe
KEY_FILE=$(find ${BASE_DIR}/fabric-ca-int-server/tls/keystore/ ${HOME}/.fabric-ca-client/msp/keystore/ -type f 2>/dev/null | head -n 1)
if [ -n "$KEY_FILE" ]; then
  mv "$KEY_FILE" ${BASE_DIR}/fabric-ca-int-server/tls/keystore/key.pem
  echo "Clé privée renommée pour Intermediate CA depuis $KEY_FILE."
else
  echo "Erreur : aucune clé privée trouvée dans ${BASE_DIR}/fabric-ca-int-server/tls/keystore/ ou ${HOME}/.fabric-ca-client/msp/keystore/ pour Intermediate CA."
  exit 1
fi
echo "Admin Intermediate CA enrôlé pour TLS."
# Copier les certificats pour l'Intermediate CA
echo "Copie des certificats pour l'Intermediate CA..."
cp ${BASE_DIR}/fabric-ca-int-server/tls/signcerts/cert.pem ${BASE_DIR}/fabric-ca-int-server/tls/cert.pem
cp ${BASE_DIR}/fabric-ca-int-server/tls/keystore/key.pem ${BASE_DIR}/fabric-ca-int-server/tls/key.pem
cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/fabric-ca-int-server/tls/tls-ca-cert.pem
echo "Certificats Intermediate CA copiés."
# Vérifier la validité du certificat TLS de l'Intermediate CA
if ! openssl verify -CAfile ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/fabric-ca-int-server/tls/cert.pem; then
  echo "Erreur : le certificat TLS de l'Intermediate CA n'est pas signé par le TLS CA."
  exit 1
fi
# Redémarrage Intermediate CA
echo "Redémarrage du conteneur Intermediate CA..."
docker-compose -f ${BASE_DIR}/docker-compose-ca.yaml restart fabric-intermediate-ca
sleep 60
# Enrôlement admin Intermediate CA avec certificat TLS correct (sans chain.pem)
echo "Enrôlement de l'admin de l'Intermediate CA..."
mkdir -p ${BASE_DIR}/fabric-ca-client/crypto/satCert-ca-int/intadmin/msp
${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://intadmin:${INT_PASSWORD}@int-ca.finance.com:7057 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --csr.hosts 'int-ca.finance.com,fabric-intermediate-ca' \
  --mspdir crypto/satCert-ca-int/intadmin/msp
echo "Admin Intermediate CA enrôlé."
# Enregistrer et enrôler les orderers
echo "Enregistrement et enrôlement des orderers..."
for i in {1..3}; do
  ORDERER_MSP_DIR="${BASE_DIR}/crypto/Orderer/orderer${i}"
 
  # Register and enroll orderer MSP
  ${BASE_DIR}/bin/fabric-ca-client register -d --id.name osn${i} --id.secret ${ORDERER_PASSWORD} \
    --id.type orderer -u https://int-ca.finance.com:7057 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --mspdir crypto/satCert-ca-int/intadmin/msp || echo " Identité osn${i} déjà enregistrée, passage à l'étape suivante"
  ${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://osn${i}:${ORDERER_PASSWORD}@int-ca.finance.com:7057 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --mspdir ${ORDERER_MSP_DIR}/msp
 
  # Register and enroll orderer TLS
  ${BASE_DIR}/bin/fabric-ca-client register -d --id.name osn${i}tls --id.secret ${ORDERER_PASSWORD} \
    --id.type orderer -u https://tls-ca.finance.com:7054 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --mspdir crypto/tls-ca/tlsadmin/msp || echo "Identité osn${i}tls déjà enregistrée, passage à l'étape suivante"
  ${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://osn${i}tls:${ORDERER_PASSWORD}@tls-ca.finance.com:7054 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --enrollment.profile tls --csr.hosts "orderer${i}.finance.com" \
    --mspdir ${ORDERER_MSP_DIR}/tls
 
  # Verify and rename private key
  KEY_FILE=$(find ${ORDERER_MSP_DIR}/tls/keystore/ ${HOME}/.fabric-ca-client/msp/keystore/ -type f 2>/dev/null | head -n 1)
  if [ -n "$KEY_FILE" ]; then
    mv "$KEY_FILE" ${ORDERER_MSP_DIR}/tls/keystore/key.pem
    echo "Clé privée renommée pour orderer${i} depuis $KEY_FILE."
  else
    echo "Erreur : aucune clé privée trouvée dans ${ORDERER_MSP_DIR}/tls/keystore/ ou ${HOME}/.fabric-ca-client/msp/keystore/ pour orderer${i}."
    exit 1
  fi
 
  # Copy TLS CA certificate
  mkdir -p ${ORDERER_MSP_DIR}/tls/tlscacerts
  cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${ORDERER_MSP_DIR}/tls/tlscacerts/tls-ca-cert.pem
 
  # Verify TLS certificate
  if [ ! -f "${ORDERER_MSP_DIR}/tls/signcerts/cert.pem" ]; then
    echo "Erreur : certificats TLS pour orderer${i} non générés dans ${ORDERER_MSP_DIR}/tls/signcerts."
    exit 1
  fi
 
  # Verify certificate validity
  if ! openssl verify -CAfile ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${ORDERER_MSP_DIR}/tls/signcerts/cert.pem; then
    echo "Erreur : le certificat TLS de orderer${i} n'est pas signé par le TLS CA."
    exit 1
  fi
done
echo "Enrôlement des orderers terminé."
# CORRECTION: Enregistrement et enrollment de l'OrdererOrg
echo "Enregistrement de l'admin OrdererOrg..."
${BASE_DIR}/bin/fabric-ca-client register -d --id.name ordererAdmin --id.secret ${ADMIN_PASSWORD} \
  --id.type admin -u https://int-ca.finance.com:7057 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir crypto/satCert-ca-int/intadmin/msp || echo "Identité ordererAdmin déjà enregistrée"
echo "Enrollment de l'admin OrdererOrg..."
mkdir -p ${BASE_DIR}/crypto/OrdererOrg/admin/msp
${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://ordererAdmin:${ADMIN_PASSWORD}@int-ca.finance.com:7057 \
  --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
  --mspdir ${BASE_DIR}/crypto/OrdererOrg/admin/msp
# Création de la structure MSP OrdererOrg
echo "Création de la structure MSP OrdererOrg..."
mkdir -p ${BASE_DIR}/crypto/OrdererOrg/msp/{admincerts,cacerts,intermediatecerts,tlscacerts,keystore,signcerts}
# Copie des certificats CA
cp ${BASE_DIR}/fabric-ca-server/ca-cert.pem ${BASE_DIR}/crypto/OrdererOrg/msp/cacerts/root-ca-cert.pem
cp ${BASE_DIR}/fabric-ca-int-server/ca-cert.pem ${BASE_DIR}/crypto/OrdererOrg/msp/intermediatecerts/int-ca-cert.pem
cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/crypto/OrdererOrg/msp/tlscacerts/tls-ca-cert.pem
# Copie du certificat admin OrdererOrg
cp ${BASE_DIR}/crypto/OrdererOrg/admin/msp/signcerts/cert.pem ${BASE_DIR}/crypto/OrdererOrg/msp/admincerts/orderer-admin-cert.pem
# Copie du certificat admin vers chaque orderer
for i in {1..3}; do
  mkdir -p ${BASE_DIR}/crypto/Orderer/orderer${i}/msp/admincerts
  cp ${BASE_DIR}/crypto/OrdererOrg/msp/admincerts/orderer-admin-cert.pem ${BASE_DIR}/crypto/Orderer/orderer${i}/msp/admincerts/
  echo "Certificat admin copié pour orderer${i}"
done
# Enregistrement et enrôlement des peers et admins
echo "Enregistrement et enrôlement des peers et admins..."
for org in {1..2}; do
  # Register and enroll admin MSP
  ${BASE_DIR}/bin/fabric-ca-client register -d --id.name adminOrg${org} --id.secret ${ADMIN_PASSWORD} \
    --id.type admin -u https://int-ca.finance.com:7057 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --mspdir crypto/satCert-ca-int/intadmin/msp || echo "Identité déjà enregistrée, passage à l'étape suivante"
  ${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://adminOrg${org}:${ADMIN_PASSWORD}@int-ca.finance.com:7057 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --mspdir ${BASE_DIR}/crypto/Org${org}/adminOrg${org}/msp
 
  # Enroll admin TLS (méthode modifiée)
  echo "Enrôlement TLS pour adminOrg${org}..."
  mkdir -p ${BASE_DIR}/crypto/Org${org}/adminOrg${org}/tls
  ${BASE_DIR}/bin/fabric-ca-client register -d --id.name adminOrg${org}tls --id.secret ${ADMIN_PASSWORD} \
    --id.type admin -u https://tls-ca.finance.com:7054 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --mspdir crypto/tls-ca/tlsadmin/msp || echo "Identité déjà enregistrée, passage à l'étape suivante"
 
  ${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://adminOrg${org}tls:${ADMIN_PASSWORD}@tls-ca.finance.com:7054 \
    --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
    --enrollment.profile tls --csr.hosts "admin-org${org}.finance.com" \
    --mspdir ${BASE_DIR}/crypto/Org${org}/adminOrg${org}/tls
 
  # Vérifier et renommer les fichiers
  if [ -f "${BASE_DIR}/crypto/Org${org}/adminOrg${org}/tls/signcerts/cert.pem" ]; then
    echo "Certificat TLS généré avec succès pour adminOrg${org}."
  else
    echo "Erreur: Échec de la génération du certificat TLS pour adminOrg${org}."
    exit 1
  fi
 
  # Copier le certificat TLS CA pour admin
  mkdir -p ${BASE_DIR}/crypto/Org${org}/adminOrg${org}/tls/tlscacerts
  cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/crypto/Org${org}/adminOrg${org}/tls/tlscacerts/tls-ca-cert.pem
 
  # Vérifier le certificat TLS admin
  if ! openssl verify -CAfile ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/crypto/Org${org}/adminOrg${org}/tls/signcerts/cert.pem; then
    echo "Erreur : le certificat TLS de adminOrg${org} n'est pas signé par le TLS CA."
    exit 1
  fi
  for peer in {1..2}; do
    # Register and enroll peer MSP
    ${BASE_DIR}/bin/fabric-ca-client register -d --id.name peer${peer}Org${org} --id.secret ${PEER_PASSWORD} \
      --id.type peer -u https://int-ca.finance.com:7057 \
      --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
      --mspdir crypto/satCert-ca-int/intadmin/msp || echo "Identité déjà enregistrée, passage à l'étape suivante"
    ${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://peer${peer}Org${org}:${PEER_PASSWORD}@int-ca.finance.com:7057 \
      --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
      --mspdir ${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/msp
   
    # Enroll peer TLS
    echo "Enrôlement TLS pour peer${peer}Org${org}..."
    mkdir -p ${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/tls
    ${BASE_DIR}/bin/fabric-ca-client register -d --id.name peer${peer}Org${org}tls --id.secret ${PEER_PASSWORD} \
      --id.type peer -u https://tls-ca.finance.com:7054 \
      --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
      --mspdir crypto/tls-ca/tlsadmin/msp || echo "Identité déjà enregistrée, passage à l'étape suivante"
   
    ${BASE_DIR}/bin/fabric-ca-client enroll -d -u https://peer${peer}Org${org}tls:${PEER_PASSWORD}@tls-ca.finance.com:7054 \
      --tls.certfiles ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem \
      --enrollment.profile tls --csr.hosts "peer${peer}-org${org}.finance.com" \
      --mspdir ${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/tls
   
    # Vérifier et renommer les fichiers
    if [ -f "${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/tls/signcerts/cert.pem" ]; then
      echo "Certificat TLS généré avec succès pour peer${peer}Org${org}."
    else
      echo "Erreur: Échec de la génération du certificat TLS pour peer${peer}Org${org}."
      exit 1
    fi
   
    # Copier le certificat TLS CA pour peer
    mkdir -p ${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/tls/tlscacerts
    cp ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/tls/tlscacerts/tls-ca-cert.pem
   
    # Vérifier le certificat TLS peer
    if [ ! -f "${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/tls/signcerts/cert.pem" ]; then
      echo "Erreur : certificats TLS pour peer${peer}Org${org} non générés dans ${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/tls."
      exit 1
    fi
    if ! openssl verify -CAfile ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem ${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/tls/signcerts/cert.pem; then
      echo "Erreur : le certificat TLS de peer${peer}Org${org} n'est pas signé par le TLS CA."
      exit 1
    fi
  done
done
# Population de admincerts et tlscacerts dans les MSP locaux des peers...
echo "Population de admincerts et tlscacerts dans les MSP locaux des peers..."
for org in {1..2}; do
  for peer in {1..2}; do
    PEER_MSP_DIR="${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/msp"
    mkdir -p "${PEER_MSP_DIR}/admincerts"
    cp "${BASE_DIR}/crypto/Org${org}/adminOrg${org}/msp/signcerts/cert.pem" "${PEER_MSP_DIR}/admincerts/admin-cert.pem"
    if [ ! -f "${PEER_MSP_DIR}/admincerts/admin-cert.pem" ]; then
      echo "Erreur : admin-cert.pem non copié dans ${PEER_MSP_DIR}/admincerts."
      exit 1
    fi
    mkdir -p "${PEER_MSP_DIR}/tlscacerts"
    cp "${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem" "${PEER_MSP_DIR}/tlscacerts/tls-ca-cert.pem"
    if [ ! -f "${PEER_MSP_DIR}/tlscacerts/tls-ca-cert.pem" ]; then
      echo "Erreur : tls-ca-cert.pem non copié dans ${PEER_MSP_DIR}/tlscacerts."
      exit 1
    fi
  done
done
echo "MSP locaux des peers peuplés avec admincerts et tlscacerts."
# Peupler les MSP d'organisations avec vérification des fichiers
echo "Peuplement des MSP d'organisations avec vérification des fichiers..."
# Fonction pour vérifier et copier les certificats
copy_cert_with_verification() {
  local src=$1
  local dest=$2
  local description=$3
 
  if [ ! -f "$src" ]; then
    echo "Erreur : fichier source $description manquant : $src"
    exit 1
  fi
 
  mkdir -p $(dirname "$dest")
  cp "$src" "$dest"
  echo "Copié $description vers $dest"
}
# OrdererOrg MSP
copy_cert_with_verification "${BASE_DIR}/fabric-ca-server/ca-cert.pem" \
  "${BASE_DIR}/crypto/OrdererOrg/msp/cacerts/root-ca-cert.pem" \
  "certificat CA racine pour OrdererOrg"
copy_cert_with_verification "${BASE_DIR}/fabric-ca-int-server/ca-cert.pem" \
  "${BASE_DIR}/crypto/OrdererOrg/msp/intermediatecerts/int-ca-cert.pem" \
  "certificat CA intermédiaire pour OrdererOrg"
copy_cert_with_verification "${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem" \
  "${BASE_DIR}/crypto/OrdererOrg/msp/tlscacerts/tls-ca-cert.pem" \
  "certificat TLS CA pour OrdererOrg"
copy_cert_with_verification "${BASE_DIR}/crypto/OrdererOrg/admin/msp/signcerts/cert.pem" \
  "${BASE_DIR}/crypto/OrdererOrg/msp/admincerts/orderer-admin-cert.pem" \
  "certificat admin orderer pour OrdererOrg"
# Org1 MSP
copy_cert_with_verification "${BASE_DIR}/fabric-ca-server/ca-cert.pem" \
  "${BASE_DIR}/crypto/Org1MSP/msp/cacerts/root-ca-cert.pem" \
  "certificat CA racine pour Org1"
copy_cert_with_verification "${BASE_DIR}/fabric-ca-int-server/ca-cert.pem" \
  "${BASE_DIR}/crypto/Org1MSP/msp/intermediatecerts/int-ca-cert.pem" \
  "certificat CA intermédiaire pour Org1"
copy_cert_with_verification "${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem" \
  "${BASE_DIR}/crypto/Org1MSP/msp/tlscacerts/tls-ca-cert.pem" \
  "certificat TLS CA pour Org1"
copy_cert_with_verification "${BASE_DIR}/crypto/Org1/adminOrg1/msp/signcerts/cert.pem" \
  "${BASE_DIR}/crypto/Org1MSP/msp/admincerts/admin-cert.pem" \
  "certificat admin pour Org1"
# Org2 MSP
copy_cert_with_verification "${BASE_DIR}/fabric-ca-server/ca-cert.pem" \
  "${BASE_DIR}/crypto/Org2MSP/msp/cacerts/root-ca-cert.pem" \
  "certificat CA racine pour Org2"
copy_cert_with_verification "${BASE_DIR}/fabric-ca-int-server/ca-cert.pem" \
  "${BASE_DIR}/crypto/Org2MSP/msp/intermediatecerts/int-ca-cert.pem" \
  "certificat CA intermédiaire pour Org2"
copy_cert_with_verification "${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem" \
  "${BASE_DIR}/crypto/Org2MSP/msp/tlscacerts/tls-ca-cert.pem" \
  "certificat TLS CA pour Org2"
copy_cert_with_verification "${BASE_DIR}/crypto/Org2/adminOrg2/msp/signcerts/cert.pem" \
  "${BASE_DIR}/crypto/Org2MSP/msp/admincerts/admin-cert.pem" \
  "certificat admin pour Org2"
echo "MSP d'organisations peuplés avec succès."
# Ajout du certificat admin dans admincerts pour les admins
for org in {1..2}; do
    ADMIN_MSP_DIR="${BASE_DIR}/crypto/Org${org}/adminOrg${org}/msp"
    mkdir -p "${ADMIN_MSP_DIR}/admincerts"
    cp "${ADMIN_MSP_DIR}/signcerts/cert.pem" "${ADMIN_MSP_DIR}/admincerts/admin-cert.pem"
    echo "Ajout du certificat admin dans admincerts/ pour Org${org}."
    if [ ! -f "${ADMIN_MSP_DIR}/admincerts/admin-cert.pem" ]; then
      echo "Erreur : admincerts/admin-cert.pem manquant dans ${ADMIN_MSP_DIR}."
      exit 1
    fi
done
# Arrêt des conteneurs CA
echo "Arrêt des conteneurs CA..."
cd ${BASE_DIR}
docker-compose -f ${BASE_DIR}/docker-compose-ca.yaml down
echo "Conteneurs CA arrêtés."
# Génération core.yaml pour chaque peer
for org in 1 2; do
  for peer in 1 2; do
    PEER_HOST="peer${peer}-org${org}.finance.com"
    PEER_PORT_VAR="PEER${peer}_ORG${org}_PORT"
    PEER_PORT=${!PEER_PORT_VAR}
    BOOTSTRAP_PEER="peer$((peer % 2 + 1))-org${org}.finance.com"
    BOOTSTRAP_PORT_VAR="PEER$((peer % 2 + 1))_ORG${org}_PORT"
    BOOTSTRAP_PORT=${!BOOTSTRAP_PORT_VAR}
    COUCHDB_HOST="couchdb-peer${peer}-org${org}.finance.com"
   
    cat > ${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/core.yaml <<EOF
logging:
  level: info
peer:
  id: ${PEER_HOST}
  networkId: finance-network
  listenAddress: 0.0.0.0:${PEER_PORT}
  address: ${PEER_HOST}:${PEER_PORT}
  localMspId: Org${org}MSP
  mspConfigPath: /etc/hyperledger/peer/msp
  BCCSP:
    Default: SW
    SW:
      Hash: SHA2
      Security: 256
      FileKeyStore:
        KeyStore:
  gossip:
    bootstrap: ${BOOTSTRAP_PEER}:${BOOTSTRAP_PORT}
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
    system: {}
    logging:
      level: info
      shim: warning
      format: '%{color}%{time:2006-01-02 15:04:05.000 MST} [%{module}] %{shortfunc} -> %{level:.4s} %{id:03x}%{color:reset} %{message}'
vm:
  endpoint: unix:///host/var/run/docker.sock
  docker:
    hostConfig:
      NetworkMode: fabric_network
      LogConfig:
        Type: json-file
        Config:
          max-size: "50m"
          max-file: "5"
      Memory: 2147483648
ledger:
  state:
    stateDatabase: CouchDB
    couchDBConfig:
      couchDBAddress: ${COUCHDB_HOST}:5984
      username: admin
      password: adminpw
      maxRetries: 3
      requestTimeout: 35s
  snapshots:
    rootDir: /var/hyperledger/production/snapshots
EOF
  done
done
# Vérifier et corriger la structure des clés MSP pour les peers
for org in {1..2}; do
  for peer in {1..2}; do
    PEER_MSP_DIR="${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/msp"
   
    # Renommer la clé privée MSP
    if [ -d "${PEER_MSP_DIR}/keystore" ]; then
      KEY_FILE=$(find "${PEER_MSP_DIR}/keystore" -type f | head -n 1)
      if [ -n "$KEY_FILE" ]; then
        mv "$KEY_FILE" "${PEER_MSP_DIR}/keystore/key.pem"
        echo "Clé privée MSP renommée pour peer${peer}Org${org}"
      fi
    fi
   
    PEER_TLS_DIR="${BASE_DIR}/crypto/Org${org}/peer${peer}Org${org}/tls"
    # Renommer la clé privée TLS
    if [ -d "${PEER_TLS_DIR}/keystore" ]; then
      KEY_FILE=$(find "${PEER_TLS_DIR}/keystore" -type f | head -n 1)
      if [ -n "$KEY_FILE" ]; then
        mv "$KEY_FILE" "${PEER_TLS_DIR}/keystore/key.pem"
        echo "Clé privée TLS renommée pour peer${peer}Org${org}"
      fi
    fi
  done
done
# Copie de core.yaml pour les commandes CLI sur l'hôte (base : Org1/peer1Org1)
echo "Copie de core.yaml pour les commandes CLI sur l'hôte..."
mkdir -p ${BASE_DIR}/config
cp ${BASE_DIR}/crypto/Org1/peer1Org1/core.yaml ${BASE_DIR}/config/core.yaml
if [ ! -f "${BASE_DIR}/config/core.yaml" ]; then
  echo "Erreur : core.yaml non copié dans ${BASE_DIR}/config."
  exit 1
fi
echo "core.yaml copié pour CLI."
# Génération orderer.yaml pour chaque orderer
echo "Génération orderer.yaml pour chaque orderer..."
for i in 1 2 3; do
  ORDERER_PORT=$((7070 + i))
  ADMIN_PORT=$((9450 + i))
  OPERATIONS_PORT=$((8440 + i))
  CLUSTER_PORT=$((9070 + i))
  cat > ${BASE_DIR}/crypto/Orderer/orderer${i}/orderer.yaml <<EOF
General:
  ListenAddress: 0.0.0.0
  ListenPort: ${ORDERER_PORT}
  TLS:
    Enabled: true
    PrivateKey: /etc/hyperledger/orderer/tls/keystore/key.pem
    Certificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
    RootCAs:
      - /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
  LocalMSPDir: /etc/hyperledger/orderer/msp
  LocalMSPID: OrdererMSP
  BootstrapFile: /etc/hyperledger/orderer/genesis.block
  BootstrapMethod: file
  Cluster:
    ListenPort: ${CLUSTER_PORT}
    ListenAddress: 0.0.0.0
    DialTimeout: 5s
    RPCTimeout: 7s
    SendBufferSize: 100
    ReplicationRetryTimeout: 5s
    ServerCertificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
    ServerPrivateKey: /etc/hyperledger/orderer/tls/keystore/key.pem
    ClientCertificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
    ClientPrivateKey: /etc/hyperledger/orderer/tls/keystore/key.pem
Consensus:
  WALDir: /var/hyperledger/production/orderer/etcdraft/wal
  SnapDir: /var/hyperledger/production/orderer/etcdraft/snapshot
FileLedger:
  Location: /var/hyperledger/production/orderer
Operations:
  ListenAddress: 0.0.0.0:${OPERATIONS_PORT}
  TLS:
    Enabled: true
    Certificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
    PrivateKey: /etc/hyperledger/orderer/tls/keystore/key.pem
    RootCAs:
      - /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
Admin:
  ListenAddress: 0.0.0.0:${ADMIN_PORT}
  TLS:
    Enabled: true
    Certificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
    PrivateKey: /etc/hyperledger/orderer/tls/keystore/key.pem
    ClientAuthRequired: true
    RootCAs:
      - /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
    ClientRootCAs:
      - /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
Metrics:
  Provider: disabled
EOF
  echo "orderer.yaml généré pour orderer${i}"
done
# Générer configtx.yaml
cat > ${BASE_DIR}/config/configtx.yaml <<EOF
Organizations:
  - &OrdererOrg
    Name: OrdererMSP
    ID: OrdererMSP
    MSPDir: ${BASE_DIR}/crypto/OrdererOrg/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('OrdererMSP.member')"
      Writers:
        Type: Signature
        Rule: "OR('OrdererMSP.member')"
      Admins:
        Type: Signature
        Rule: "OR('OrdererMSP.admin')"
  - &Org1
    Name: Org1MSP
    ID: Org1MSP
    MSPDir: ${BASE_DIR}/crypto/Org1MSP/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('Org1MSP.member')"
      Writers:
        Type: Signature
        Rule: "OR('Org1MSP.member')"
      Admins:
        Type: Signature
        Rule: "OR('Org1MSP.admin')"
      Endorsement:
        Type: Signature
        Rule: "OR('Org1MSP.member')"
    AnchorPeers:
      - Host: peer1-org1.finance.com
        Port: ${PEER1_ORG1_PORT}
      - Host: peer2-org1.finance.com
        Port: ${PEER2_ORG1_PORT}
  - &Org2
    Name: Org2MSP
    ID: Org2MSP
    MSPDir: ${BASE_DIR}/crypto/Org2MSP/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('Org2MSP.member')"
      Writers:
        Type: Signature
        Rule: "OR('Org2MSP.member')"
      Admins:
        Type: Signature
        Rule: "OR('Org2MSP.admin')"
      Endorsement:
        Type: Signature
        Rule: "OR('Org2MSP.member')"
    AnchorPeers:
      - Host: peer1-org2.finance.com
        Port: ${PEER1_ORG2_PORT}
      - Host: peer2-org2.finance.com
        Port: ${PEER2_ORG2_PORT}
Capabilities:
  Channel: &ChannelCapabilities
    V2_0: true
  Orderer: &OrdererCapabilities
    V2_0: true
  Application: &ApplicationCapabilities
    V2_0: true
Orderer:
  OrdererType: etcdraft
  Addresses:
    - orderer1.finance.com:${ORDERER1_PORT}
    - orderer2.finance.com:${ORDERER2_PORT}
    - orderer3.finance.com:${ORDERER3_PORT}
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 10
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 KB
  EtcdRaft:
    Consenters:
      - Host: orderer1.finance.com
        Port: 9071
        ClientTLSCert: ${BASE_DIR}/crypto/Orderer/orderer1/tls/signcerts/cert.pem
        ServerTLSCert: ${BASE_DIR}/crypto/Orderer/orderer1/tls/signcerts/cert.pem
      - Host: orderer2.finance.com
        Port: 9072
        ClientTLSCert: ${BASE_DIR}/crypto/Orderer/orderer2/tls/signcerts/cert.pem
        ServerTLSCert: ${BASE_DIR}/crypto/Orderer/orderer2/tls/signcerts/cert.pem
      - Host: orderer3.finance.com
        Port: 9073
        ClientTLSCert: ${BASE_DIR}/crypto/Orderer/orderer3/tls/signcerts/cert.pem
        ServerTLSCert: ${BASE_DIR}/crypto/Orderer/orderer3/tls/signcerts/cert.pem
  Organizations:
    - *OrdererOrg
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    BlockValidation:
      Type: ImplicitMeta
      Rule: "ANY Writers"
Application:
  Organizations:
    - *Org1
    - *Org2
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    Endorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
    LifecycleEndorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
Channel:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
Profiles:
  TokenChannel:
    Consortium: SampleConsortium
    Policies:
      Readers:
        Type: ImplicitMeta
        Rule: "ANY Readers"
      Writers:
        Type: ImplicitMeta
        Rule: "ANY Writers"
      Admins:
        Type: ImplicitMeta
        Rule: "MAJORITY Admins"
    Capabilities:
      <<: *ChannelCapabilities
    Application:
      Capabilities:
        <<: *ApplicationCapabilities
      Organizations:
        - *Org1
        - *Org2
      Policies:
        Readers:
          Type: ImplicitMeta
          Rule: "ANY Readers"
        Writers:
          Type: ImplicitMeta
          Rule: "ANY Writers"
        Admins:
          Type: ImplicitMeta
          Rule: "MAJORITY Admins"
        Endorsement:
          Type: ImplicitMeta
          Rule: "MAJORITY Endorsement"
        LifecycleEndorsement:
          Type: ImplicitMeta
          Rule: "MAJORITY Endorsement"
  OrdererGenesis:
    Policies:
      Readers:
        Type: ImplicitMeta
        Rule: "ANY Readers"
      Writers:
        Type: ImplicitMeta
        Rule: "ANY Writers"
      Admins:
        Type: ImplicitMeta
        Rule: "MAJORITY Admins"
    Capabilities:
      <<: *ChannelCapabilities
    Orderer:
      OrdererType: etcdraft
      Addresses:
        - orderer1.finance.com:${ORDERER1_PORT}
        - orderer2.finance.com:${ORDERER2_PORT}
        - orderer3.finance.com:${ORDERER3_PORT}
      BatchTimeout: 2s
      BatchSize:
        MaxMessageCount: 10
        AbsoluteMaxBytes: 99 MB
        PreferredMaxBytes: 512 KB
      EtcdRaft:
        Consenters:
          - Host: orderer1.finance.com
            Port: 9071
            ClientTLSCert: ${BASE_DIR}/crypto/Orderer/orderer1/tls/signcerts/cert.pem
            ServerTLSCert: ${BASE_DIR}/crypto/Orderer/orderer1/tls/signcerts/cert.pem
          - Host: orderer2.finance.com
            Port: 9072
            ClientTLSCert: ${BASE_DIR}/crypto/Orderer/orderer2/tls/signcerts/cert.pem
            ServerTLSCert: ${BASE_DIR}/crypto/Orderer/orderer2/tls/signcerts/cert.pem
          - Host: orderer3.finance.com
            Port: 9073
            ClientTLSCert: ${BASE_DIR}/crypto/Orderer/orderer3/tls/signcerts/cert.pem
            ServerTLSCert: ${BASE_DIR}/crypto/Orderer/orderer3/tls/signcerts/cert.pem
      Organizations:
        - *OrdererOrg
      Capabilities:
        <<: *OrdererCapabilities
      Policies:
        Readers:
          Type: ImplicitMeta
          Rule: "ANY Readers"
        Writers:
          Type: ImplicitMeta
          Rule: "ANY Writers"
        Admins:
          Type: ImplicitMeta
          Rule: "MAJORITY Admins"
        BlockValidation:
          Type: ImplicitMeta
          Rule: "ANY Writers"
    Consortiums:
      SampleConsortium:
        Organizations:
          - *Org1
          - *Org2
EOF
echo "Fichier configtx.yaml créé."
if [ ! -f "${BASE_DIR}/config/configtx.yaml" ]; then
  echo "Erreur : configtx.yaml non généré dans ${BASE_DIR}/config."
  exit 1
fi
# Génération du bloc de genèse
echo "Génération du bloc de genèse..."
${BASE_DIR}/bin/configtxgen -profile OrdererGenesis -channelID system-channel -outputBlock ${BASE_DIR}/channel-artifacts/genesis.block
if [ ! -f "${BASE_DIR}/channel-artifacts/genesis.block" ]; then
  echo "Erreur : bloc de genèse non généré dans ${BASE_DIR}/channel-artifacts."
  exit 1
fi
echo "Bloc de genèse créé."
# Génération de la transaction de création du canal
echo "Génération de la transaction de création du canal..."
${BASE_DIR}/bin/configtxgen -profile TokenChannel -outputCreateChannelTx ${BASE_DIR}/channel-artifacts/channel.tx -channelID tokenchannel
if [ ! -f "${BASE_DIR}/channel-artifacts/channel.tx" ]; then
  echo "Erreur : transaction de création du canal non générée dans ${BASE_DIR}/channel-artifacts."
  exit 1
fi
echo "Transaction de création du canal créée."
# Génération des transactions d'ancrage pour chaque organisation
echo "Génération des transactions d'ancrage..."
for org in {1..2}; do
  ${BASE_DIR}/bin/configtxgen -profile TokenChannel -outputAnchorPeersUpdate ${BASE_DIR}/channel-artifacts/Org${org}MSPanchors.tx -channelID tokenchannel -asOrg Org${org}MSP
  if [ ! -f "${BASE_DIR}/channel-artifacts/Org${org}MSPanchors.tx" ]; then
    echo "Erreur : transaction d'ancrage pour Org${org}MSP non générée dans ${BASE_DIR}/channel-artifacts."
    exit 1
  fi
  echo "Transaction d'ancrage pour Org${org}MSP créée."
done
# Copie du bloc de genèse aux orderers
echo "Copie du bloc de genèse aux orderers..."
for i in {1..3}; do
  # Vérifier que le répertoire existe
  mkdir -p ${BASE_DIR}/crypto/Orderer/orderer${i}
  # Supprimer un éventuel répertoire genesis.block créé par erreur
  if [ -d "${BASE_DIR}/crypto/Orderer/orderer${i}/genesis.block" ]; then
    rm -rf "${BASE_DIR}/crypto/Orderer/orderer${i}/genesis.block"
    echo "Répertoire ${BASE_DIR}/crypto/Orderer/orderer${i}/genesis.block supprimé."
  fi
  # Vérifier que le fichier source existe
  if [ ! -f "${BASE_DIR}/channel-artifacts/genesis.block" ]; then
    echo "Erreur : fichier ${BASE_DIR}/channel-artifacts/genesis.block manquant."
    exit 1
  fi
  # Copier le fichier genesis.block dans le répertoire monté
  cp ${BASE_DIR}/channel-artifacts/genesis.block \
     ${BASE_DIR}/crypto/Orderer/orderer${i}/genesis.block
  # Vérification que le fichier a été copié et n'est pas un répertoire
  if [ ! -f "${BASE_DIR}/crypto/Orderer/orderer${i}/genesis.block" ]; then
    echo "Erreur : bloc de genèse non copié ou n'est pas un fichier dans ${BASE_DIR}/crypto/Orderer/orderer${i}."
    exit 1
  fi
  echo "Bloc de genèse copié pour orderer${i}."
done
echo "Bloc de genèse copié pour tous les orderers."
# Création du réseau Docker manuellement pour éviter les problèmes de prefix
echo "Création du réseau Docker..."
docker network create --driver bridge --subnet 172.18.0.0/16 --gateway 172.18.0.1 fabric_network || true
echo "Réseau Docker créé."
# Créer docker-compose.yaml pour tout le réseau
echo "Création du fichier docker-compose.yaml..."
cat > ${BASE_DIR}/docker-compose.yaml <<EOF
version: "3.9"
networks:
  fabric_network:
    external: true
services:
  # ------------------- ORDERERS -------------------
  fabric-orderer1:
    image: hyperledger/fabric-orderer:2.5
    container_name: fabric-orderer1
    hostname: orderer1.finance.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7071
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_BOOTSTRAPFILE=/etc/hyperledger/orderer/genesis.block
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem]
      - ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_CLUSTER_LISTENPORT=9071
      - ORDERER_GENERAL_CLUSTER_SERVERCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_CLUSTER_SERVERPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
    volumes:
      - ${BASE_DIR}/crypto/Orderer/orderer1/msp:/etc/hyperledger/orderer/msp
      - ${BASE_DIR}/crypto/Orderer/orderer1/tls:/etc/hyperledger/orderer/tls
      - ${BASE_DIR}/crypto/Orderer/orderer1/genesis.block:/etc/hyperledger/orderer/genesis.block
      - ${BASE_DIR}/ledger/orderer1:/var/hyperledger/production/orderer
    ports:
      - "7071:7071"
      - "9451:9451"
      - "8441:8441"
      - "9071:9071"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.2
    command: orderer
    restart: unless-stopped
  fabric-orderer2:
    image: hyperledger/fabric-orderer:2.5
    container_name: fabric-orderer2
    hostname: orderer2.finance.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7072
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_BOOTSTRAPFILE=/etc/hyperledger/orderer/genesis.block
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem]
      - ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_CLUSTER_LISTENPORT=9072
      - ORDERER_GENERAL_CLUSTER_SERVERCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_CLUSTER_SERVERPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
    volumes:
      - ${BASE_DIR}/crypto/Orderer/orderer2/msp:/etc/hyperledger/orderer/msp
      - ${BASE_DIR}/crypto/Orderer/orderer2/tls:/etc/hyperledger/orderer/tls
      - ${BASE_DIR}/crypto/Orderer/orderer2/genesis.block:/etc/hyperledger/orderer/genesis.block
      - ${BASE_DIR}/ledger/orderer2:/var/hyperledger/production/orderer
    ports:
      - "7072:7072"
      - "9452:9452"
      - "8442:8442"
      - "9072:9072"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.3
    command: orderer
    restart: unless-stopped
  fabric-orderer3:
    image: hyperledger/fabric-orderer:2.5
    container_name: fabric-orderer3
    hostname: orderer3.finance.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7073
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_BOOTSTRAPFILE=/etc/hyperledger/orderer/genesis.block
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem]
      - ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_CLUSTER_LISTENPORT=9073
      - ORDERER_GENERAL_CLUSTER_SERVERCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_CLUSTER_SERVERPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/key.pem
    volumes:
      - ${BASE_DIR}/crypto/Orderer/orderer3/msp:/etc/hyperledger/orderer/msp
      - ${BASE_DIR}/crypto/Orderer/orderer3/tls:/etc/hyperledger/orderer/tls
      - ${BASE_DIR}/crypto/Orderer/orderer3/genesis.block:/etc/hyperledger/orderer/genesis.block
      - ${BASE_DIR}/ledger/orderer3:/var/hyperledger/production/orderer
    ports:
      - "7073:7073"
      - "9453:9453"
      - "8443:8443"
      - "9073:9073"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.4
    command: orderer
    restart: unless-stopped
  # ------------------- PEERS ORG1 -------------------
  peer1-org1:
    image: hyperledger/fabric-peer:2.5
    container_name: peer1-org1
    hostname: peer1-org1.finance.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_ID=peer1-org1.finance.com
      - CORE_PEER_ADDRESS=peer1-org1.finance.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer1-org1.finance.com:8051
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:8051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer2-org1.finance.com:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1-org1.finance.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_network
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb-peer1-org1.finance.com:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
      - CORE_CHAINCODE_BUILDER=hyperledger/fabric-ccenv:latest
      - CORE_CHAINCODE_GOLANG_RUNTIME=hyperledger/fabric-baseos:latest
    volumes:
      - ${BASE_DIR}/crypto/Org1/peer1Org1:/etc/hyperledger/peer
      - ${BASE_DIR}/ledger/peer1org1:/var/hyperledger/production
      - /var/run/docker.sock:/host/var/run/docker.sock
    ports:
      - "7051:7051"
      - "8051:8051"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.5
    depends_on:
      - couchdb-peer1-org1
    command: peer node start
    restart: unless-stopped
  peer2-org1:
    image: hyperledger/fabric-peer:2.5
    container_name: peer2-org1
    hostname: peer2-org1.finance.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_ID=peer2-org1.finance.com
      - CORE_PEER_ADDRESS=peer2-org1.finance.com:7052
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_CHAINCODEADDRESS=peer2-org1.finance.com:8052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:8052
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1-org1.finance.com:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer2-org1.finance.com:7052
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_network
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb-peer2-org1.finance.com:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
      - CORE_CHAINCODE_BUILDER=hyperledger/fabric-ccenv:latest
      - CORE_CHAINCODE_GOLANG_RUNTIME=hyperledger/fabric-baseos:latest
    volumes:
      - ${BASE_DIR}/crypto/Org1/peer2Org1:/etc/hyperledger/peer
      - ${BASE_DIR}/ledger/peer2org1:/var/hyperledger/production
      - /var/run/docker.sock:/host/var/run/docker.sock
    ports:
      - "7052:7052"
      - "8052:8052"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.6
    depends_on:
      - couchdb-peer2-org1
    command: peer node start
    restart: unless-stopped
  # ------------------- PEERS ORG2 -------------------
  peer1-org2:
    image: hyperledger/fabric-peer:2.5
    container_name: peer1-org2
    hostname: peer1-org2.finance.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_ID=peer1-org2.finance.com
      - CORE_PEER_ADDRESS=peer1-org2.finance.com:7053
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7053
      - CORE_PEER_CHAINCODEADDRESS=peer1-org2.finance.com:8053
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:8053
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer2-org2.finance.com:7054
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1-org2.finance.com:7053
      - CORE_PEER_LOCALMSPID=Org2MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_network
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb-peer1-org2.finance.com:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
      - CORE_CHAINCODE_BUILDER=hyperledger/fabric-ccenv:latest
      - CORE_CHAINCODE_GOLANG_RUNTIME=hyperledger/fabric-baseos:latest
    volumes:
      - ${BASE_DIR}/crypto/Org2/peer1Org2:/etc/hyperledger/peer
      - ${BASE_DIR}/ledger/peer1org2:/var/hyperledger/production
      - /var/run/docker.sock:/host/var/run/docker.sock
    ports:
      - "7053:7053"
      - "8053:8053"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.7
    depends_on:
      - couchdb-peer1-org2
    command: peer node start
    restart: unless-stopped
  peer2-org2:
    image: hyperledger/fabric-peer:2.5
    container_name: peer2-org2
    hostname: peer2-org2.finance.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_ID=peer2-org2.finance.com
      - CORE_PEER_ADDRESS=peer2-org2.finance.com:7054
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7054
      - CORE_PEER_CHAINCODEADDRESS=peer2-org2.finance.com:8054
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:8054
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1-org2.finance.com:7053
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer2-org2.finance.com:7054
      - CORE_PEER_LOCALMSPID=Org2MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/tls/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/peer/tls/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_network
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb-peer2-org2.finance.com:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
      - CORE_CHAINCODE_BUILDER=hyperledger/fabric-ccenv:latest
      - CORE_CHAINCODE_GOLANG_RUNTIME=hyperledger/fabric-baseos:latest
    volumes:
      - ${BASE_DIR}/crypto/Org2/peer2Org2:/etc/hyperledger/peer
      - ${BASE_DIR}/ledger/peer2org2:/var/hyperledger/production
      - /var/run/docker.sock:/host/var/run/docker.sock
    ports:
      - "7054:7054"
      - "8054:8054"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.8
    depends_on:
      - couchdb-peer2-org2
    command: peer node start
    restart: unless-stopped
  # ------------------- CLI -------------------
  fabric-cli:
    image: hyperledger/fabric-peer:2.5
    container_name: fabric-cli
    hostname: cli.finance.com
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp
      - CORE_PEER_ADDRESS=peer1-org1.finance.com:7051
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
    volumes:
      - ${BASE_DIR}/crypto/Org1/peer1Org1:/etc/hyperledger/peer
      - ${BASE_DIR}/crypto/Org1/adminOrg1/msp:/etc/hyperledger/adminOrg1/msp
      - ${BASE_DIR}/crypto/Org2/adminOrg2/msp:/etc/hyperledger/adminOrg2/msp
      - ${BASE_DIR}/crypto/Orderer/orderer1/tls:/etc/hyperledger/orderer/tls
      - ${BASE_DIR}/channel-artifacts:/etc/hyperledger/channel-artifacts
      - ${BASE_DIR}/chaincode:/etc/hyperledger/chaincode
      - ${BASE_DIR}/peerSAT_COM:/etc/hyperledger/peerSAT_COM
    networks:
      fabric_network:
        ipv4_address: 172.18.0.9
    command: /bin/sh
    tty: true
    stdin_open: true
    restart: unless-stopped
  # ------------------- COUCHDB -------------------
  couchdb-peer1-org1:
    image: couchdb:3.4
    container_name: couchdb-peer1-org1
    hostname: couchdb-peer1-org1.finance.com
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "5984:5984"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.10
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5984/"]
      interval: 30s
      timeout: 10s
      retries: 5
    restart: unless-stopped
  couchdb-peer2-org1:
    image: couchdb:3.4
    container_name: couchdb-peer2-org1
    hostname: couchdb-peer2-org1.finance.com
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "5985:5984"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.11
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5984/"]
      interval: 30s
      timeout: 10s
      retries: 5
    restart: unless-stopped
  couchdb-peer1-org2:
    image: couchdb:3.4
    container_name: couchdb-peer1-org2
    hostname: couchdb-peer1-org2.finance.com
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "5986:5984"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.12
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5984/"]
      interval: 30s
      timeout: 10s
      retries: 5
    restart: unless-stopped
  couchdb-peer2-org2:
    image: couchdb:3.4
    container_name: couchdb-peer2-org2
    hostname: couchdb-peer2-org2.finance.com
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "5987:5984"
    networks:
      fabric_network:
        ipv4_address: 172.18.0.13
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5984/"]
      interval: 30s
      timeout: 10s
      retries: 5
    restart: unless-stopped
EOF
echo "Fichier docker-compose.yaml créé."
if [ ! -f "${BASE_DIR}/docker-compose.yaml" ]; then
  echo "Erreur : docker-compose.yaml non généré dans ${BASE_DIR}."
  exit 1
fi
# Démarrage des conteneurs avec Docker Compose
echo "Démarrage des conteneurs avec Docker Compose..."
cd ${BASE_DIR}
docker-compose -f ${BASE_DIR}/docker-compose.yaml up -d
echo "Conteneurs démarrés. Vérifiez avec 'docker ps'."
sleep 120
# Vérifier que tous les conteneurs sont en cours d'exécution
if [ $(docker ps -f network=fabric_network | wc -l) -ne 13 ]; then
  echo "Erreur : tous les conteneurs ne sont pas en cours d'exécution. Vérifiez les logs avec 'docker logs <nom_conteneur>'."
  exit 1
fi
# Créer le canal tokenchannel
echo "Création du canal tokenchannel dans le conteneur CLI..."
docker exec fabric-cli env \
  FABRIC_LOGGING_SPEC=INFO \
  CORE_PEER_LOCALMSPID=Org2MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg2/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org2.finance.com:${PEER1_ORG2_PORT} \
  peer channel create -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com -c tokenchannel -f /etc/hyperledger/channel-artifacts/channel.tx \
  --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem \
  --outputBlock /etc/hyperledger/peerSAT_COM/tokenchannel.block
if [ ! -f "${BASE_DIR}/peerSAT_COM/tokenchannel.block" ]; then
  echo "Erreur : bloc de canal tokenchannel non créé dans ${BASE_DIR}/peerSAT_COM."
  exit 1
fi
echo "Canal tokenchannel créé."
sudo chown -R $USER:$USER ./*
# Joindre les peers au canal
echo "Joindre les peers au canal tokenchannel..."
for org in {1..2}; do
  for peer in {1..2}; do
    docker exec fabric-cli env \
      FABRIC_LOGGING_SPEC=INFO \
      CORE_PEER_LOCALMSPID=Org${org}MSP \
      CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${org}/msp \
      CORE_PEER_TLS_ENABLED=true \
      CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
      CORE_PEER_ADDRESS=peer${peer}-org${org}.finance.com:$((PEER${peer}_ORG${org}_PORT)) \
      peer channel join -b /etc/hyperledger/peerSAT_COM/tokenchannel.block
    echo "Peer${peer}Org${org} a rejoint le canal tokenchannel."
  done
done
# Mettre à jour les peers d'ancrage
echo "Mise à jour des peers d'ancrage..."
for org in {1..2}; do
  docker exec fabric-cli env \
    FABRIC_LOGGING_SPEC=INFO \
    CORE_PEER_LOCALMSPID=Org${org}MSP \
    CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${org}/msp \
    CORE_PEER_TLS_ENABLED=true \
    CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
    CORE_PEER_ADDRESS=peer1-org${org}.finance.com:$((PEER1_ORG${org}_PORT)) \
    peer channel update -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com -c tokenchannel -f /etc/hyperledger/channel-artifacts/Org${org}MSPanchors.tx \
    --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
  echo "Peer d'ancrage mis à jour pour Org${org}MSP."
done
# Créer l'image Docker pour le chaincode
echo "Création de l'image Docker pour le chaincode..."
cd ${BASE_DIR}/chaincode/token
cat > Dockerfile <<EOF
FROM golang:1.23
WORKDIR /go/src/token
COPY . .
RUN go mod tidy
RUN go get github.com/hyperledger/fabric-chaincode-go/shim
RUN go get github.com/hyperledger/fabric-contract-api-go/contractapi@v1.2.2
RUN CGO_ENABLED=0 GOOS=linux go build -o token
CMD ["./token"]
EOF
docker build -t token-chaincode:latest .
if [ $? -ne 0 ]; then
  echo "Erreur : échec de la construction de l'image Docker du chaincode."
  exit 1
fi
echo "Image Docker du chaincode créée."
# Créer docker-compose pour le chaincode
echo "Création du fichier docker-compose-chaincode.yaml..."
cat > ${BASE_DIR}/docker-compose-chaincode.yaml <<EOF
version: '3.8'
networks:
  fabric_network:
    external: true
services:
  token-chaincode:
    image: token-chaincode:latest
    container_name: token-chaincode
    hostname: token-chaincode
    environment:
      - CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999
      - CHAINCODE_ID=${CHAINCODE_ID}
    ports:
      - "9999:9999"
    networks:
      - fabric_network
    restart: unless-stopped
EOF
echo "Fichier docker-compose-chaincode.yaml créé."
if [ ! -f "${BASE_DIR}/docker-compose-chaincode.yaml" ]; then
  echo "Erreur : docker-compose-chaincode.yaml non généré dans ${BASE_DIR}."
  exit 1
fi
# Démarrer le conteneur du chaincode
echo "Démarrage du conteneur du chaincode..."
cd ${BASE_DIR}
docker-compose -f ${BASE_DIR}/docker-compose-chaincode.yaml up -d
echo "Conteneur du chaincode démarré."
sleep 60
# Installer le chaincode sur les peers
echo "Installation du chaincode sur les peers..."
for org in {1..2}; do
  for peer in {1..2}; do
    docker exec fabric-cli env \
      FABRIC_LOGGING_SPEC=INFO \
      CORE_PEER_LOCALMSPID=Org${org}MSP \
      CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${org}/msp \
      CORE_PEER_TLS_ENABLED=true \
      CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
      CORE_PEER_ADDRESS=peer${peer}-org${org}.finance.com:$((PEER${peer}_ORG${org}_PORT)) \
      peer lifecycle chaincode install /etc/hyperledger/chaincode/token/token.tar.gz
    if [ $? -ne 0 ]; then
      echo "Erreur : échec de l'installation du chaincode sur peer${peer}Org${org}."
      exit 1
    fi
    echo "Chaincode installé sur peer${peer}Org${org}."
  done
done
# Récupérer l'ID du chaincode
echo "Récupération de l'ID du chaincode..."
INSTALLED_OUTPUT=$(docker exec fabric-cli env \
  FABRIC_LOGGING_SPEC=INFO \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org1.finance.com:${PEER1_ORG1_PORT} \
  peer lifecycle chaincode queryinstalled)
echo "$INSTALLED_OUTPUT"
CHAINCODE_ID=$(echo "$INSTALLED_OUTPUT" | grep "Label: token" -A1 | grep "Package ID" | awk '{print $3}' | cut -d',' -f1)
if [ -z "$CHAINCODE_ID" ]; then
  echo "Erreur : impossible de récupérer l'ID du chaincode pour label 'token'."
  exit 1
fi
echo "ID du chaincode : $CHAINCODE_ID"
# Approuver le chaincode pour chaque organisation
echo "Approbation du chaincode pour chaque organisation..."
for org in {1..2}; do
  docker exec fabric-cli env \
    FABRIC_LOGGING_SPEC=INFO \
    CORE_PEER_LOCALMSPID=Org${org}MSP \
    CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${org}/msp \
    CORE_PEER_TLS_ENABLED=true \
    CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
    CORE_PEER_ADDRESS=peer1-org${org}.finance.com:$((PEER1_ORG${org}_PORT)) \
    peer lifecycle chaincode approveformyorg -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com \
    --channelID tokenchannel --name token --version 1.0 --package-id ${CHAINCODE_ID} --sequence 1 \
    --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
  if [ $? -ne 0 ]; then
    echo "Erreur : échec de l'approbation du chaincode pour Org${org}MSP."
    exit 1
  fi
  echo "Chaincode approuvé pour Org${org}MSP."
  sleep 10 # Pause pour permettre la propagation
done
# Vérifier l'état d'approbation du chaincode
echo "Vérification de l'état d'approbation du chaincode..."
docker exec fabric-cli env \
  FABRIC_LOGGING_SPEC=INFO \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org1.finance.com:${PEER1_ORG1_PORT} \
  peer lifecycle chaincode checkcommitreadiness -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com \
  --channelID tokenchannel --name token --version 1.0 --sequence 1 \
  --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem
if [ $? -ne 0 ]; then
  echo "Erreur: échec de la vérification de l'état d'approbation du chaincode."
  exit 1
fi
echo "État d'approbation du chaincode vérifié."
# Valider le chaincode
echo "Validation du chaincode sur le canal tokenchannel..."
docker exec fabric-cli env \
  FABRIC_LOGGING_SPEC=INFO \
  CORE_PEER_LOCALMSPID=Org2MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg2/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org2.finance.com:${PEER1_ORG2_PORT} \
  peer lifecycle chaincode commit -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com \
  --channelID tokenchannel --name token --version 1.0 --sequence 1 \
  --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem \
  --peerAddresses peer1-org1.finance.com:${PEER1_ORG1_PORT} --tlsRootCertFiles /etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  --peerAddresses peer1-org2.finance.com:${PEER1_ORG2_PORT} --tlsRootCertFiles /etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
if [ $? -ne 0 ]; then
  echo "Erreur : échec de la validation du chaincode."
  exit 1
fi
echo "Chaincode validé sur le canal tokenchannel."
# Initialiser le chaincode
echo "Initialisation du chaincode..."
docker exec fabric-cli env \
  FABRIC_LOGGING_SPEC=INFO \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org1.finance.com:${PEER1_ORG1_PORT} \
  peer chaincode invoke -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com \
  --channelID tokenchannel --name token \
  --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem \
  -c '{"function":"Init","Args":[]}' \
  --peerAddresses peer1-org1.finance.com:${PEER1_ORG1_PORT} \
  --tlsRootCertFiles /etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  --peerAddresses peer1-org2.finance.com:${PEER1_ORG2_PORT} \
  --tlsRootCertFiles /etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
if [ $? -ne 0 ]; then
  echo "Erreur : échec de l'initialisation du chaincode."
  exit 1
fi
echo "Chaincode initialisé."
sleep 10
# Tester le chaincode avec une opération de mint
echo "Test du chaincode avec une opération de mint..."
docker exec fabric-cli env \
  FABRIC_LOGGING_SPEC=INFO \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org1.finance.com:${PEER1_ORG1_PORT} \
  peer chaincode invoke -o orderer1.finance.com:${ORDERER1_PORT} --ordererTLSHostnameOverride orderer1.finance.com \
  --channelID tokenchannel --name token \
  --tls --cafile /etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem \
  -c '{"function":"Mint","Args":["adminOrg1", "1000"]}' \
  --peerAddresses peer1-org1.finance.com:${PEER1_ORG1_PORT} \
  --tlsRootCertFiles /etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  --peerAddresses peer1-org2.finance.com:${PEER1_ORG2_PORT} \
  --tlsRootCertFiles /etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem
if [ $? -ne 0 ]; then
  echo "Erreur : échec de l'opération de mint."
  exit 1
fi
echo "Opération de mint exécutée."
sleep 20
# Vérifier le solde
echo "Vérification du solde pour adminOrg1..."
docker exec fabric-cli env \
  FABRIC_LOGGING_SPEC=INFO \
  CORE_PEER_LOCALMSPID=Org1MSP \
  CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp \
  CORE_PEER_TLS_ENABLED=true \
  CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
  CORE_PEER_ADDRESS=peer1-org1.finance.com:${PEER1_ORG1_PORT} \
  peer chaincode query --channelID tokenchannel --name token \
  -c '{"function":"BalanceOf","Args":["adminOrg1"]}'
if [ $? -ne 0 ]; then
  echo "Erreur : échec de la vérification du solde."
  exit 1
fi
echo "Solde vérifié pour adminOrg1."
# Vérification finale du réseau
echo "Vérification finale du réseau..."
for org in {1..2}; do
  for peer in {1..2}; do
    docker exec fabric-cli env \
      FABRIC_LOGGING_SPEC=INFO \
      CORE_PEER_LOCALMSPID=Org${org}MSP \
      CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg${org}/msp \
      CORE_PEER_TLS_ENABLED=true \
      CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem \
      CORE_PEER_ADDRESS=peer${peer}-org${org}.finance.com:$((PEER${peer}_ORG${org}_PORT)) \
      peer channel list | grep tokenchannel
    if [ $? -ne 0 ]; then
      echo "Erreur : peer${peer}Org${org} n'est pas connecté au canal tokenchannel."
      exit 1
    fi
    echo "Peer${peer}Org${org} est connecté au canal tokenchannel."
  done
done
# Tester la connectivité des orderers
echo "Test de la connectivité des orderers..."
for i in {1..3}; do
  ORDERER_PORT=$((7070 + i))
  if ! openssl s_client -connect 127.0.0.1:${ORDERER_PORT} -CAfile ${BASE_DIR}/crypto/tls-ca-root-cert/tls-ca-cert.pem < /dev/null 2>/dev/null; then
    echo "Erreur : échec de la connexion TLS à orderer${i} sur le port ${ORDERER_PORT}."
    exit 1
  fi
  echo "Connexion TLS réussie à orderer${i} sur le port ${ORDERER_PORT}."
done
echo "Réseau Hyperledger Fabric déployé avec succès !"
echo "Vous pouvez interagir avec le réseau en utilisant le conteneur CLI :"
echo "docker exec -it fabric-cli /bin/sh"
echo "Exemple : pour vérifier le solde, exécutez dans le conteneur :"
echo "env FABRIC_LOGGING_SPEC=INFO CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/adminOrg1/msp CORE_PEER_TLS_ENABLED=true CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/tls/tlscacerts/tls-ca-cert.pem CORE_PEER_ADDRESS=peer1-org1.finance.com:${PEER1_ORG1_PORT} peer chaincode query --channelID tokenchannel --name token -c '{\"function\":\"BalanceOf\",\"Args\":[\"adminOrg1\"] }'"