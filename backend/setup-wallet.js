#!/usr/bin/env node
/**
 * setup-wallet.js
 * 
 * Importe les identités admin dans les wallets Fabric SDK.
 * Gère deux formats :
 *   1) Réseau Fabric standard : crypto/Org{N}/adminOrg{N}/msp/signcerts + keystore
 *   2) Format legacy local  : wallet/adminOrg{N}/cert.pem + key.pem
 * 
 * Usage:
 *   node setup-wallet.js
 *   FABRIC_NETWORK_PATH=../hyperledger-fabric-network node setup-wallet.js
 */

require('dotenv').config();
const { Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');

const FABRIC_NETWORK_PATH = process.env.FABRIC_NETWORK_PATH || '../hyperledger-fabric-network';
const NETWORK_BASE_PATH = path.resolve(__dirname, FABRIC_NETWORK_PATH);
const WALLET_BASE_PATH = path.resolve(__dirname, process.env.WALLET_PATH || './wallet');

const ORGS = [
    { name: 'org1', mspId: 'Org1MSP', number: '1' },
    { name: 'org2', mspId: 'Org2MSP', number: '2' },
];

async function setupWallets() {
    console.log('\n=== Configuration des Wallets ===');
    console.log(`  Fabric Network : ${NETWORK_BASE_PATH}`);
    console.log(`  Wallet Path    : ${WALLET_BASE_PATH}\n`);

    for (const org of ORGS) {
        try {
            const walletPath = path.join(WALLET_BASE_PATH, org.name);
            if (!fs.existsSync(walletPath)) {
                fs.mkdirSync(walletPath, { recursive: true });
            }

            const wallet = await Wallets.newFileSystemWallet(walletPath);

            // Vérifier si déjà importé
            const existing = await wallet.get('admin');
            if (existing) {
                console.log(`✓ ${org.name}: identité admin déjà présente dans ${walletPath}`);
                continue;
            }

            let cert = null, key = null;

            // 1) Chemin réseau Fabric standard
            const adminMspPath = path.join(NETWORK_BASE_PATH, 'crypto', `Org${org.number}`, `adminOrg${org.number}`, 'msp');
            if (fs.existsSync(adminMspPath)) {
                const signcertsPath = path.join(adminMspPath, 'signcerts');
                const keystorePath = path.join(adminMspPath, 'keystore');

                const certFiles = fs.readdirSync(signcertsPath).filter(f => f.endsWith('.pem'));
                const keyFiles = fs.readdirSync(keystorePath).filter(f => f.endsWith('.pem') || f.endsWith('_sk'));

                if (certFiles.length && keyFiles.length) {
                    cert = fs.readFileSync(path.join(signcertsPath, certFiles[0])).toString();
                    key = fs.readFileSync(path.join(keystorePath, keyFiles[0])).toString();
                    console.log(`  ${org.name}: certificats trouvés dans ${adminMspPath}`);
                }
            }

            // 2) Fallback : wallet/adminOrg{N}/cert.pem + key.pem
            if (!cert || !key) {
                const legacyPath = path.join(WALLET_BASE_PATH, `adminOrg${org.number}`);
                const certPath = path.join(legacyPath, 'cert.pem');
                const keyPath = path.join(legacyPath, 'key.pem');

                if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
                    cert = fs.readFileSync(certPath).toString();
                    key = fs.readFileSync(keyPath).toString();
                    console.log(`  ${org.name}: certificats trouvés dans ${legacyPath} (legacy)`);
                }
            }

            if (!cert || !key) {
                console.error(`✗ ${org.name}: aucun certificat trouvé`);
                continue;
            }

            await wallet.put('admin', {
                credentials: { certificate: cert, privateKey: key },
                mspId: org.mspId,
                type: 'X.509',
            });

            console.log(`✓ ${org.name}: identité admin importée (${org.mspId}) → ${walletPath}/admin.id`);

        } catch (error) {
            console.error(`✗ ${org.name}: erreur — ${error.message}`);
        }
    }

    console.log('\n=== Configuration terminée ===\n');
}

setupWallets().catch(console.error);
