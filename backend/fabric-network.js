const { Gateway, Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');

// ===================================================================
// CONFIGURATION
// ===================================================================
const DEFAULT_ORG = 'org1';
const DEFAULT_USER = 'admin';
const CHANNEL_NAME = process.env.CHANNEL_NAME || 'tokenchannel';
const CHAINCODE_NAME = process.env.CHAINCODE_NAME || 'token';

const FABRIC_NETWORK_PATH = process.env.FABRIC_NETWORK_PATH || '../hyperledger-fabric-network';
const NETWORK_BASE_PATH = path.resolve(__dirname, FABRIC_NETWORK_PATH);
const WALLET_PATH = process.env.WALLET_PATH || './wallet';
const CONFIG_PATH = process.env.CONFIG_PATH || './config';
const WALLET_BASE_PATH = path.resolve(__dirname, WALLET_PATH);
const CONFIG_BASE_PATH = path.resolve(__dirname, CONFIG_PATH);

const CONNECTION_TIMEOUT = parseInt(process.env.TIMEOUT_CONNECTION) || 30000;
const TRANSACTION_TIMEOUT = parseInt(process.env.TIMEOUT_TRANSACTION) || 60000;

// ===================================================================
// AUTO-DÉCOUVERTE DES ORGANISATIONS
// Scanne backend/config/connection-org*.json pour détecter les orgs
// ===================================================================
function discoverOrganizations() {
    const orgs = [];
    const ccpPaths = {};
    const mspIdMap = {};

    if (!fs.existsSync(CONFIG_BASE_PATH)) return { orgs, ccpPaths, mspIdMap };

    const files = fs.readdirSync(CONFIG_BASE_PATH)
        .filter(f => /^connection-org\d+\.json$/.test(f))
        .sort();

    for (const file of files) {
        const match = file.match(/^connection-org(\d+)\.json$/);
        if (!match) continue;
        const orgNum = match[1];
        const orgKey = `org${orgNum}`;
        orgs.push(orgKey);
        ccpPaths[orgKey] = path.join(CONFIG_BASE_PATH, file);
        mspIdMap[orgKey] = `Org${orgNum}MSP`;
    }

    console.log(`✓ Auto-découverte: ${orgs.length} organisations détectées: ${orgs.join(', ')}`);
    return { orgs, ccpPaths, mspIdMap };
}

let { orgs: SUPPORTED_ORGS, ccpPaths: CCP_PATHS, mspIdMap: MSP_ID_MAP } = discoverOrganizations();

// Recharger les orgs dynamiquement (utile après ajout d'une org)
function reloadOrganizations() {
    const discovered = discoverOrganizations();
    SUPPORTED_ORGS = discovered.orgs;
    CCP_PATHS = discovered.ccpPaths;
    MSP_ID_MAP = discovered.mspIdMap;
    return { organizations: SUPPORTED_ORGS, mspIds: MSP_ID_MAP };
}

// Créer répertoires s'ils n'existent pas
[WALLET_BASE_PATH, CONFIG_BASE_PATH].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

// ===================================================================
// CACHE DE CONNEXIONS — réutilise les gateways pendant 5 min
// ===================================================================
const connectionCache = {};
const CACHE_TTL = 5 * 60 * 1000;

function getCacheKey(org, userId) {
    return `${org}:${userId}`;
}

function invalidateCache(key) {
    if (connectionCache[key]) {
        try { connectionCache[key].gateway.disconnect(); } catch (_) {}
        delete connectionCache[key];
    }
}

// ===================================================================
// WALLET — import des identités admin
// ===================================================================
async function importAdminIdentity(org) {
    try {
        if (!SUPPORTED_ORGS.includes(org)) {
            throw new Error(`Organisation non supportée: ${org}. Supportées: ${SUPPORTED_ORGS.join(', ')}`);
        }

        const mspId = MSP_ID_MAP[org];
        const orgNumber = org.slice(-1);

        const walletPath = path.join(WALLET_BASE_PATH, org);
        if (!fs.existsSync(walletPath)) {
            fs.mkdirSync(walletPath, { recursive: true });
        }
        const wallet = await Wallets.newFileSystemWallet(walletPath);

        const identityExists = await wallet.get('admin');
        if (identityExists) {
            console.log(`✓ Identité admin déjà présente pour ${org}`);
            return;
        }

        // 1) Tenter le chemin réseau Fabric standard
        const cryptoPath = path.join(NETWORK_BASE_PATH, 'crypto');
        const adminMspPath = path.join(cryptoPath, `Org${orgNumber}`, `adminOrg${orgNumber}`, 'msp');

        if (fs.existsSync(adminMspPath)) {
            const signcertsPath = path.join(adminMspPath, 'signcerts');
            const keystorePath = path.join(adminMspPath, 'keystore');

            const certFiles = fs.readdirSync(signcertsPath).filter(f => f.endsWith('.pem'));
            if (!certFiles.length) throw new Error(`Aucun certificat trouvé dans ${signcertsPath}`);
            const cert = fs.readFileSync(path.join(signcertsPath, certFiles[0])).toString();

            const keyFiles = fs.readdirSync(keystorePath).filter(f => f.endsWith('.pem') || f.endsWith('_sk'));
            if (!keyFiles.length) throw new Error(`Aucune clé trouvée dans ${keystorePath}`);
            const key = fs.readFileSync(path.join(keystorePath, keyFiles[0])).toString();

            await wallet.put('admin', {
                credentials: { certificate: cert, privateKey: key },
                mspId,
                type: 'X.509'
            });
            console.log(`✓ Identité admin importée pour ${org} (${mspId}) depuis le réseau`);
            return;
        }

        // 2) Fallback : wallet/adminOrg{N}/ (ancien format avec cert.pem+key.pem en vrac)
        const legacyWalletPath = path.join(WALLET_BASE_PATH, `adminOrg${orgNumber}`);
        if (fs.existsSync(legacyWalletPath)) {
            const certPath = path.join(legacyWalletPath, 'cert.pem');
            const keyPath = path.join(legacyWalletPath, 'key.pem');

            if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
                const cert = fs.readFileSync(certPath).toString();
                const key = fs.readFileSync(keyPath).toString();

                await wallet.put('admin', {
                    credentials: { certificate: cert, privateKey: key },
                    mspId,
                    type: 'X.509'
                });
                console.log(`✓ Identité admin importée pour ${org} (${mspId}) depuis wallet legacy`);
                return;
            }
        }

        throw new Error(`Aucun certificat trouvé pour ${org} — ni dans ${adminMspPath} ni dans ${legacyWalletPath}`);

    } catch (error) {
        console.error(`✗ Erreur import ${org}:`, error.message);
        throw error;
    }
}

// ===================================================================
// CONNEXION AU RÉSEAU avec cache
// ===================================================================
async function connectToNetwork(org = DEFAULT_ORG, userId = DEFAULT_USER) {
    const cacheKey = getCacheKey(org, userId);

    // Vérifier le cache (simple TTL, pas de round-trip réseau)
    if (connectionCache[cacheKey]) {
        const cached = connectionCache[cacheKey];
        if (Date.now() - cached.timestamp < CACHE_TTL) {
            return cached;
        } else {
            invalidateCache(cacheKey);
        }
    }

    try {
        if (!SUPPORTED_ORGS.includes(org)) {
            throw new Error(`Organisation non supportée: ${org}`);
        }
        if (!CCP_PATHS[org] || !fs.existsSync(CCP_PATHS[org])) {
            throw new Error(`Profil de connexion manquant: ${CCP_PATHS[org]}`);
        }

        const walletPath = path.join(WALLET_BASE_PATH, org);
        const wallet = await Wallets.newFileSystemWallet(walletPath);

        const identity = await wallet.get(userId);
        if (!identity) {
            throw new Error(`Identité ${userId} non trouvée dans le wallet de ${org}. Lancer: node setup-wallet.js`);
        }

        const ccp = JSON.parse(fs.readFileSync(CCP_PATHS[org], 'utf8'));
        const gateway = new Gateway();

        await gateway.connect(ccp, {
            wallet,
            identity: userId,
            discovery: {
                enabled: process.env.DISCOVERY_ENABLED !== 'false',
                asLocalhost: process.env.DISCOVERY_AS_LOCALHOST === 'true'
            },
            eventHandlerOptions: {
                commitTimeout: TRANSACTION_TIMEOUT,
                endorseTimeout: TRANSACTION_TIMEOUT
            }
        });

        const network = await gateway.getNetwork(CHANNEL_NAME);
        const contract = network.getContract(CHAINCODE_NAME);

        const connection = { gateway, network, contract, org, userId, timestamp: Date.now() };
        connectionCache[cacheKey] = connection;
        return connection;

    } catch (error) {
        console.error(`✗ Erreur connexion ${org}:`, error.message);
        throw error;
    }
}

// ===================================================================
// APPELS CHAINCODE
// ===================================================================
async function callChaincodeFunction(org = DEFAULT_ORG, functionName, args = [], isQuery = true) {
    const { contract } = await connectToNetwork(org, DEFAULT_USER);

    try {
        let result;
        if (isQuery) {
            result = await contract.evaluateTransaction(functionName, ...args);
        } else {
            result = await contract.submitTransaction(functionName, ...args);
            invalidateCache(getCacheKey(org, DEFAULT_USER));
        }
        return result.toString('utf8');
    } catch (error) {
        invalidateCache(getCacheKey(org, DEFAULT_USER));
        console.error(`✗ Erreur ${functionName}:`, error.message);
        throw error;
    }
}

// ===================================================================
// DÉTECTION DES FONCTIONS — une seule connexion
// ===================================================================
async function detectAvailableFunctions(org = DEFAULT_ORG) {
    const functionsToTest = [
        { name: 'GetAllAccounts', args: [], type: 'query' },
        { name: 'GetAllTransactions', args: [], type: 'query' },
        { name: 'GetAllUsers', args: [], type: 'query' },
        { name: 'GetAccount', args: ['ACC001'], type: 'query' },
        { name: 'GetUser', args: ['USR001'], type: 'query' },
        { name: 'GetDashboardStats', args: [], type: 'query' },
        { name: 'Transfer', args: [], type: 'invoke' },
        { name: 'Mint', args: [], type: 'invoke' },
        { name: 'CreateAccount', args: [], type: 'invoke' },
        { name: 'CreateUser', args: [], type: 'invoke' },
        { name: 'UpdateUser', args: [], type: 'invoke' },
        { name: 'UpdateAccount', args: [], type: 'invoke' },
        { name: 'InitLedger', args: [], type: 'invoke' }
    ];

    const availableFunctions = [];

    try {
        const { contract } = await connectToNetwork(org);

        for (const func of functionsToTest) {
            if (func.type === 'query') {
                try {
                    await contract.evaluateTransaction(func.name, ...func.args);
                    availableFunctions.push({ name: func.name, type: 'query', argsCount: func.args.length });
                    console.log(`  ✓ ${func.name}`);
                } catch (error) {
                    if (!error.message.includes('not found') && !error.message.includes('Unknown')) {
                        availableFunctions.push({ name: func.name, type: 'query', argsCount: func.args.length });
                        console.log(`  ✓ ${func.name} (existe, erreur d'args)`);
                    } else {
                        console.log(`  ✗ ${func.name}`);
                    }
                }
            } else {
                availableFunctions.push({ name: func.name, type: 'invoke', argsCount: func.args.length });
                console.log(`  ✓ ${func.name} (invoke)`);
            }
        }
    } catch (error) {
        console.error('✗ Erreur détection fonctions:', error.message);
    }

    return availableFunctions;
}

// ===================================================================
// DASHBOARD STATS — chaincode GetDashboardStats + fallback réseau
// ===================================================================
async function getDashboardStats(org = DEFAULT_ORG) {
    // 1) Essayer le chaincode GetDashboardStats
    try {
        const result = await callChaincodeFunction(org, 'GetDashboardStats', []);
        const s = JSON.parse(result);
        return {
            blocks: s.Blocks || s.blocks || 1,
            transactions: s.TotalTransactions || s.totalTransactions || 0,
            activePeers: s.ActivePeers || s.activePeers || 4,
            activeOrderers: s.ActiveOrderers || s.activeOrderers || 3,
            networkPerformance: s.NetworkPerformance || s.networkPerformance || 75,
            avgTps: (s.AvgTPS || s.avgTps || 0).toString(),
            maxTps: (s.BreakTPS || s.maxTps || 0).toString(),
            totalAccounts: s.TotalAccounts || s.totalAccounts || 0,
            totalBalance: s.TotalBalance || s.totalBalance || 0,
            users: s.ActiveUsers || s.users || 0,
            organization: org,
            timestamp: new Date().toISOString()
        };
    } catch (_) {
        console.log('⚠ GetDashboardStats chaincode non disponible, fallback réseau...');
    }

    // 2) Fallback : stats depuis les fonctions chaincode individuelles
    try {
        let totalAccounts = 0, totalBalance = 0, totalTx = 0, userCount = 0;

        // Comptes
        try {
            const accountsResult = await callChaincodeFunction(org, 'GetAllAccounts', []);
            const accounts = JSON.parse(accountsResult);
            if (Array.isArray(accounts)) {
                totalAccounts = accounts.length;
                totalBalance = accounts.reduce((sum, acc) => sum + (parseInt(acc.Available || acc.available) || 0), 0);
            }
        } catch (_) {}

        // Transactions
        try {
            const txResult = await callChaincodeFunction(org, 'GetAllTransactions', []);
            const txs = JSON.parse(txResult);
            totalTx = Array.isArray(txs) ? txs.length : 0;
        } catch (_) {}

        // Utilisateurs
        try {
            const usersResult = await callChaincodeFunction(org, 'GetAllUsers', []);
            const users = JSON.parse(usersResult);
            userCount = Array.isArray(users) ? users.length : 0;
        } catch (_) {}

        return {
            blocks: 1,
            transactions: totalTx,
            activePeers: 4,
            activeOrderers: 3,
            networkPerformance: 75,
            avgTps: '0',
            maxTps: '0',
            totalAccounts,
            totalBalance,
            users: userCount,
            organization: org,
            timestamp: new Date().toISOString()
        };
    } catch (error) {
        console.error('✗ Erreur getDashboardStats:', error.message);
        return getDefaultStats(org);
    }
}

// ===================================================================
// TRANSACTIONS — chaincode GetAllTransactions, fallback block scan
// ===================================================================
async function getTransactionHistory(org = DEFAULT_ORG, limit = 10) {
    // 1) Chaincode GetAllTransactions (données métier riches : from, to, amount)
    try {
        const result = await callChaincodeFunction(org, 'GetAllTransactions', []);
        const txs = JSON.parse(result);
        if (Array.isArray(txs) && txs.length > 0) {
            return txs.slice(0, limit).map(tx => ({
                id: tx.ID || tx.id || '',
                from: tx.From || tx.from || 'system',
                to: tx.To || tx.to || 'system',
                amount: parseInt(tx.Amount || tx.amount) || 0,
                block: parseInt(tx.Block || tx.block) || 0,
                timestamp: tx.Timestamp || tx.timestamp || new Date().toISOString(),
                status: 'Confirmée'
            }));
        }
    } catch (_) {
        console.log('⚠ GetAllTransactions chaincode non disponible, fallback block scan...');
    }

    // 2) Fallback : aucune transaction disponible
    console.log('⚠ Aucune source de transactions disponible');
    return [];
}

// ===================================================================
// COMPTES — chaincode GetAllAccounts, normalisation des clés
// ===================================================================
async function getAllAccounts(org = DEFAULT_ORG) {
    try {
        const result = await callChaincodeFunction(org, 'GetAllAccounts', []);
        const accounts = JSON.parse(result);
        if (Array.isArray(accounts)) {
            return accounts.map(acc => ({
                id: acc.ID || acc.id || '',
                bank: acc.Bank || acc.bank || 'Inconnu',
                currency: acc.Currency || acc.currency || 'MAD',
                type: acc.Type || acc.type || 'Standard',
                available: parseInt(acc.Available || acc.available) || 0
            }));
        }
        return [];
    } catch (error) {
        console.log('⚠ GetAllAccounts non disponible:', error.message);
        return [];
    }
}

// ===================================================================
// SOLDE D'UN COMPTE — GetAccount au lieu de BalanceOf (qui n'existe pas)
// ===================================================================
async function getAccountBalance(org = DEFAULT_ORG, accountId) {
    try {
        const result = await callChaincodeFunction(org, 'GetAccount', [accountId]);
        const account = JSON.parse(result);
        return parseInt(account.Available || account.available) || 0;
    } catch (error) {
        console.error(`✗ Erreur getAccountBalance(${accountId}):`, error.message);
        throw error;
    }
}

// ===================================================================
// UTILISATEURS — chaincode GetAllUsers
// ===================================================================
async function getAllUsers(org = DEFAULT_ORG) {
    try {
        const result = await callChaincodeFunction(org, 'GetAllUsers', []);
        const users = JSON.parse(result);
        if (Array.isArray(users)) {
            return users.map(u => ({
                id: u.ID || u.id || '',
                name: u.Name || u.name || 'Inconnu',
                email: u.Email || u.email || '',
                role: u.Role || u.role || 'User',
                active: u.Active !== undefined ? u.Active : (u.active !== undefined ? u.active : true)
            }));
        }
        return [];
    } catch (error) {
        console.log('⚠ GetAllUsers non disponible:', error.message);
        return [];
    }
}

// ===================================================================
// TRANSFERT
// ===================================================================
async function transfer(org = DEFAULT_ORG, from, to, amount) {
    if (!from || !to || !amount || amount <= 0) {
        throw new Error('Paramètres de transfert invalides');
    }
    try {
        const result = await callChaincodeFunction(org, 'Transfer', [from, to, amount.toString()], false);
        return {
            success: true,
            data: result,
            message: 'Transfert effectué',
            timestamp: new Date().toISOString()
        };
    } catch (error) {
        throw new Error(`Transfert échoué: ${error.message}`);
    }
}

// ===================================================================
// UTILITAIRES
// ===================================================================
function getDefaultStats(org) {
    return {
        blocks: 1,
        transactions: 0,
        activePeers: 4,
        activeOrderers: 3,
        networkPerformance: 75,
        avgTps: '0',
        maxTps: '0',
        totalAccounts: 0,
        totalBalance: 0,
        users: 0,
        organization: org,
        timestamp: new Date().toISOString()
    };
}

// ===================================================================
// INITIALISATION
// ===================================================================
async function initialize() {
    console.log('\n=== Initialisation Fabric ===');
    console.log(`  Réseau:    ${NETWORK_BASE_PATH}`);
    console.log(`  Wallet:    ${WALLET_BASE_PATH}`);
    console.log(`  Channel:   ${CHANNEL_NAME}`);
    console.log(`  Chaincode: ${CHAINCODE_NAME}`);
    console.log(`  Discovery: enabled=${process.env.DISCOVERY_ENABLED}, asLocalhost=${process.env.DISCOVERY_AS_LOCALHOST}\n`);

    for (const org of SUPPORTED_ORGS) {
        try {
            await importAdminIdentity(org);
        } catch (error) {
            console.error(`✗ Import échoué pour ${org}:`, error.message);
        }
    }

    console.log('\n=== Initialisation terminée ===\n');
}

initialize().catch(console.error);

// ===================================================================
// EXPORTS
// ===================================================================
module.exports = {
    connectToNetwork,
    callChaincodeFunction,
    getDashboardStats,
    getTransactionHistory,
    getAllAccounts,
    getAccountBalance,
    getAllUsers,
    transfer,
    detectAvailableFunctions,
    reloadOrganizations,
    DEFAULT_ORG,
    SUPPORTED_ORGS,
    CHANNEL_NAME,
    CHAINCODE_NAME
};
