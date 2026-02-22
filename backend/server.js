const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
require('dotenv').config();
const fabricService = require('./fabric-network');

const app = express();
const PORT = process.env.PORT || 4000;

// Middlewares
app.use(cors({
    origin: ['http://localhost:5173', 'http://localhost:3000', 'http://localhost:3001'],
    credentials: true
}));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Logging middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
    next();
});

// Middleware de validation pour les paramètres
const validateOrgParam = (req, res, next) => {
    const org = req.query.org || req.body.org || fabricService.DEFAULT_ORG;
    if (!fabricService.SUPPORTED_ORGS.includes(org)) {
        return res.status(400).json({
            success: false,
            error: `Organisation invalide: ${org}`
        });
    }
    next();
};

// Appliquer le middleware de validation
app.use('/api/call', validateOrgParam);
app.use('/api/transfer', validateOrgParam);
app.use('/api/mint', validateOrgParam);

// Route racine — info API
app.get('/', (req, res) => {
    res.json({
        name: 'Blockchain Backend API',
        version: '1.0.0',
        status: 'running',
        endpoints: [
            'GET  /api/health',
            'GET  /api/organizations',
            'GET  /api/functions',
            'POST /api/call',
            'GET  /api/dashboard',
            'GET  /api/stats',
            'GET  /api/transactions',
            'GET  /api/accounts',
            'GET  /api/accounts/:accountId/balance',
            'POST /api/accounts/create',
            'POST /api/transfer',
            'POST /api/mint',
            'GET  /api/users',
            'POST /api/users/create'
        ],
        timestamp: new Date().toISOString()
    });
});

// Health check amélioré — teste la connexion Fabric via un appel chaincode léger
app.get('/api/health', async (req, res) => {
    try {
        const org = req.query.org || fabricService.DEFAULT_ORG;
        // Tester la connexion en appelant une fonction chaincode légère
        await fabricService.connectToNetwork(org);

        res.json({
            success: true,
            status: 'healthy',
            blockchain: {
                channel: fabricService.CHANNEL_NAME,
                chaincode: fabricService.CHAINCODE_NAME,
                organization: org
            },
            uptime: process.uptime(),
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(503).json({
            success: false,
            status: 'unhealthy',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Détecter les fonctions disponibles
app.get('/api/functions', async (req, res) => {
    try {
        const org = req.query.org || fabricService.DEFAULT_ORG;
        console.log(`Détection des fonctions pour: ${org}`);
        const functions = await fabricService.detectAvailableFunctions(org);

        res.json({
            success: true,
            data: functions,
            organization: org,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Appeler une fonction du chaincode
app.post('/api/call', async (req, res) => {
    try {
        const org = req.body.org || req.query.org || fabricService.DEFAULT_ORG;
        const { functionName, args = [], isQuery = true } = req.body;

        if (!functionName) {
            return res.status(400).json({
                success: false,
                error: 'functionName est requis'
            });
        }

        console.log(`Appel: ${functionName}(${args.join(', ')}) via ${org}`);
        const result = await fabricService.callChaincodeFunction(org, functionName, args, isQuery);

        let parsedResult = result;
        try {
            parsedResult = JSON.parse(result);
        } catch (error) {
            // ...existing code...
        }

        res.json({
            success: true,
            data: parsedResult,
            function: functionName,
            organization: org,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message,
            function: req.body.functionName
        });
    }
});

// Dashboard stats
app.get('/api/dashboard', async (req, res) => {
    try {
        const org = req.query.org || fabricService.DEFAULT_ORG;
        const stats = await fabricService.getDashboardStats(org);

        res.json({
            success: true,
            data: stats
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Transactions history
app.get('/api/transactions', async (req, res) => {
    try {
        const org = req.query.org || fabricService.DEFAULT_ORG;
        const limit = parseInt(req.query.limit) || 10;
        const transactions = await fabricService.getTransactionHistory(org, limit);

        res.json({
            success: true,
            data: transactions,
            count: transactions.length,
            organization: org
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get all accounts
app.get('/api/accounts', async (req, res) => {
    try {
        const org = req.query.org || fabricService.DEFAULT_ORG;
        const accounts = await fabricService.getAllAccounts(org);

        res.json({
            success: true,
            data: accounts,
            count: accounts.length,
            organization: org
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get account balance (utilise GetAccount du chaincode, pas BalanceOf)
app.get('/api/accounts/:accountId/balance', async (req, res) => {
    try {
        const org = req.query.org || fabricService.DEFAULT_ORG;
        const { accountId } = req.params;

        const balance = await fabricService.getAccountBalance(org, accountId);

        res.json({
            success: true,
            data: {
                accountId,
                balance,
                organization: org
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Transfer tokens
app.post('/api/transfer', async (req, res) => {
    try {
        const org = req.body.org || req.query.org || fabricService.DEFAULT_ORG;
        const { from, to, amount } = req.body;

        if (!from || !to || !amount) {
            return res.status(400).json({
                success: false,
                error: 'from, to, et amount sont requis'
            });
        }

        console.log(`Transfert: ${from} -> ${to}: ${amount} (${org})`);
        const result = await fabricService.transfer(org, from, to, amount);

        res.json({
            success: true,
            data: result,
            organization: org
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Mint tokens
app.post('/api/mint', async (req, res) => {
    try {
        const org = req.body.org || req.query.org || fabricService.DEFAULT_ORG;
        const { to, amount } = req.body;

        if (!to || !amount) {
            return res.status(400).json({
                success: false,
                error: 'to et amount sont requis'
            });
        }

        console.log(`Mint: ${to} += ${amount} (${org})`);
        const result = await fabricService.callChaincodeFunction(org, 'Mint', [to, amount.toString()], false);

        res.json({
            success: true,
            data: result,
            function: 'Mint',
            organization: org,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Create account
app.post('/api/accounts/create', async (req, res) => {
    try {
        const org = req.body.org || req.query.org || fabricService.DEFAULT_ORG;
        const { accountId, bank, type } = req.body;

        if (!accountId || !bank || !type) {
            return res.status(400).json({
                success: false,
                error: 'accountId, bank et type sont requis'
            });
        }

        console.log(`Création compte: ${accountId} (${bank}, ${type}) via ${org}`);
        const result = await fabricService.callChaincodeFunction(
            org, 'CreateAccount', [accountId, bank, 'MAD', type, '0'], false
        );

        res.json({
            success: true,
            data: result,
            organization: org,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get all users from chaincode
app.get('/api/users', async (req, res) => {
    try {
        const org = req.query.org || fabricService.DEFAULT_ORG;
        const users = await fabricService.getAllUsers(org);

        res.json({
            success: true,
            data: users,
            count: users.length,
            organization: org
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Create user
app.post('/api/users/create', async (req, res) => {
    try {
        const org = req.body.org || req.query.org || fabricService.DEFAULT_ORG;
        const { userId, name, email, role } = req.body;

        if (!userId || !name || !email || !role) {
            return res.status(400).json({
                success: false,
                error: 'userId, name, email et role sont requis'
            });
        }

        console.log(`Création utilisateur: ${userId} (${name}) via ${org}`);
        const result = await fabricService.callChaincodeFunction(
            org, 'CreateUser', [userId, name, email, role, 'true'], false
        );

        res.json({
            success: true,
            data: result,
            organization: org,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Update user (name, email, role, active)
app.put('/api/users/:userId', async (req, res) => {
    try {
        const org = req.body.org || req.query.org || fabricService.DEFAULT_ORG;
        const { userId } = req.params;
        const { name, email, role, active } = req.body;

        if (!name || !email || !role) {
            return res.status(400).json({
                success: false,
                error: 'name, email et role sont requis'
            });
        }

        const activeStr = active === false ? 'false' : 'true';
        console.log(`Update utilisateur: ${userId} active=${activeStr} via ${org}`);
        const result = await fabricService.callChaincodeFunction(
            org, 'UpdateUser', [userId, name, email, role, activeStr], false
        );

        res.json({
            success: true,
            data: result,
            organization: org,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Toggle user active status
app.patch('/api/users/:userId/toggle', async (req, res) => {
    try {
        const org = req.body.org || req.query.org || fabricService.DEFAULT_ORG;
        const { userId } = req.params;

        // Get current user first
        const userResult = await fabricService.callChaincodeFunction(org, 'GetUser', [userId]);
        const user = JSON.parse(userResult);
        const newActive = !(user.active === true || user.Active === true);
        const activeStr = newActive ? 'true' : 'false';

        const name = user.name || user.Name;
        const email = user.email || user.Email;
        const role = user.role || user.Role;

        console.log(`Toggle user ${userId}: active=${activeStr}`);
        const result = await fabricService.callChaincodeFunction(
            org, 'UpdateUser', [userId, name, email, role, activeStr], false
        );

        res.json({
            success: true,
            data: { ...user, active: newActive },
            organization: org,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Update account (bank, currency, type, blocked)
app.put('/api/accounts/:accountId', async (req, res) => {
    try {
        const org = req.body.org || req.query.org || fabricService.DEFAULT_ORG;
        const { accountId } = req.params;
        const { bank, currency, type, blocked } = req.body;

        if (!bank || !type) {
            return res.status(400).json({
                success: false,
                error: 'bank et type sont requis'
            });
        }

        const blockedStr = blocked === true ? 'true' : 'false';
        console.log(`Update account: ${accountId} blocked=${blockedStr} via ${org}`);
        const result = await fabricService.callChaincodeFunction(
            org, 'UpdateAccount', [accountId, bank, currency || 'MAD', type, blockedStr], false
        );

        res.json({
            success: true,
            data: result,
            organization: org,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Toggle account blocked status
app.patch('/api/accounts/:accountId/toggle-block', async (req, res) => {
    try {
        const org = req.body.org || req.query.org || fabricService.DEFAULT_ORG;
        const { accountId } = req.params;

        // Get current account
        const accResult = await fabricService.callChaincodeFunction(org, 'GetAccount', [accountId]);
        const acc = JSON.parse(accResult);
        const newBlocked = !(acc.blocked === true || acc.Blocked === true);
        const blockedStr = newBlocked ? 'true' : 'false';

        const bank = acc.bank || acc.Bank;
        const currency = acc.currency || acc.Currency || 'MAD';
        const type = acc.type || acc.Type;

        console.log(`Toggle block account ${accountId}: blocked=${blockedStr}`);
        const result = await fabricService.callChaincodeFunction(
            org, 'UpdateAccount', [accountId, bank, currency, type, blockedStr], false
        );

        res.json({
            success: true,
            data: { ...acc, blocked: newBlocked },
            organization: org,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Get dashboard stats from chaincode
app.get('/api/stats', async (req, res) => {
    try {
        const org = req.query.org || fabricService.DEFAULT_ORG;
        const result = await fabricService.callChaincodeFunction(org, 'GetDashboardStats', []);
        let stats = JSON.parse(result);

        res.json({
            success: true,
            data: stats,
            organization: org
        });
    } catch (error) {
        // Fallback to fabric-network stats
        try {
            const org = req.query.org || fabricService.DEFAULT_ORG;
            const stats = await fabricService.getDashboardStats(org);
            res.json({ success: true, data: stats });
        } catch (fallbackError) {
            res.status(500).json({ success: false, error: error.message });
        }
    }
});

// Routes du dashboard
app.get('/api/organizations', (req, res) => {
    res.json({
        success: true,
        data: fabricService.SUPPORTED_ORGS,
        default: fabricService.DEFAULT_ORG,
        timestamp: new Date().toISOString()
    });
});

// Recharger les organisations (après ajout d'une nouvelle org)
app.post('/api/organizations/reload', (req, res) => {
    try {
        const result = fabricService.reloadOrganizations();
        res.json({
            success: true,
            message: 'Organisations rechargées avec succès',
            data: result,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Error handling
app.use((error, req, res, next) => {
    console.error('Erreur serveur:', error);
    
    const statusCode = error.statusCode || 500;
    const message = process.env.NODE_ENV === 'production' 
        ? 'Erreur interne du serveur' 
        : error.message;
    
    res.status(statusCode).json({
        success: false,
        error: message,
        ...(process.env.NODE_ENV !== 'production' && { stack: error.stack })
    });
});

app.listen(PORT, () => {
    console.log(`\n✓ Backend API démarré sur http://localhost:${PORT}`);
    console.log(`  Environnement: ${process.env.NODE_ENV}`);
    console.log(`  Channel: ${fabricService.CHANNEL_NAME}`);
    console.log(`  Chaincode: ${fabricService.CHAINCODE_NAME}`);
    console.log(`  Organisations: ${fabricService.SUPPORTED_ORGS.join(', ')}`);
    console.log(`\n  Endpoints disponibles:`);
    console.log(`  - GET  /api/health`);
    console.log(`  - GET  /api/organizations`);
    console.log(`  - GET  /api/functions`);
    console.log(`  - POST /api/call`);
    console.log(`  - GET  /api/dashboard`);
    console.log(`  - GET  /api/transactions`);
    console.log(`  - GET  /api/accounts`);
    console.log(`  - GET  /api/accounts/:accountId/balance`);
    console.log(`  - POST /api/transfer`);
    console.log(`  - POST /api/mint`);
    console.log(`  - POST /api/accounts/create`);
    console.log(`  - GET  /api/users`);
    console.log(`  - POST /api/users/create`);
    console.log(`  - GET  /api/stats\n`);
});