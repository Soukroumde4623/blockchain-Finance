// src/contexts/BlockchainContext.tsx
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

// Résoudre l'URL de l'API — en dev le proxy Vite redirige /api vers le backend
const API_BASE_URL = '/api';

// Interfaces basées sur tes composants et données
export interface DashboardStats {
  blocks: number;
  transactions: number;
  activePeers: number;
  activeOrderers: number;
  networkPerformance: number;
  avgTps: string;
  maxTps: string;
  totalAccounts: number;
  totalBalance: number;
  organization: string;
  timestamp: string;
}

export interface Transaction {
  id: string;
  from: string;
  to: string;
  amount: number;
  block: number;
  timestamp: string;
  status: string;
}

export interface BlockchainAccount {
  id: string;
  bank: string;
  currency: string;
  type: string;
  available: number;
  blocked: boolean;
}

export interface BlockchainUser {
  id: string;
  name: string;
  email: string;
  role: string;
  active: boolean;
}

// Interfaces pour les requêtes
export interface TransferRequest {
  from: string;
  to: string;
  amount: number;
}

export interface CreateAccountRequest {
  accountId: string;
  bank: string;
  type: string;
}

interface BlockchainContextType {
  stats: DashboardStats | null;
  transactions: Transaction[];
  accounts: BlockchainAccount[];
  blockchainUsers: BlockchainUser[];
  organizations: string[];
  currentOrg: string;
  loading: boolean;
  refreshing: boolean;
  error: string | null;

  refreshStats: () => Promise<void>;
  refreshTransactions: (limit?: number) => Promise<void>;
  refreshAccounts: () => Promise<void>;
  refreshUsers: () => Promise<void>;
  refreshAll: () => Promise<void>;

  mintTokens: (to: string, amount: number) => Promise<void>;
  transferTokens: (from: string, to: string, amount: number) => Promise<void>;
  createAccount: (accountId: string, bank: string, type: string) => Promise<void>;
  updateAccount: (accountId: string, bank: string, currency: string, type: string, blocked: boolean) => Promise<void>;
  toggleAccountBlock: (accountId: string) => Promise<void>;
  createUser: (userId: string, name: string, email: string, role: string) => Promise<void>;
  updateUser: (userId: string, name: string, email: string, role: string, active: boolean) => Promise<void>;
  toggleUserActive: (userId: string) => Promise<void>;

  setCurrentOrg: (org: string) => void;
  clearError: () => void;
}

const BlockchainContext = createContext<BlockchainContextType | undefined>(undefined);

export const useBlockchain = () => {
  const context = useContext(BlockchainContext);
  if (!context) {
    throw new Error('useBlockchain must be used within BlockchainProvider');
  }
  return context;
};

interface BlockchainProviderProps {
  children: ReactNode;
}

export const BlockchainProvider: React.FC<BlockchainProviderProps> = ({ children }) => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [accounts, setAccounts] = useState<BlockchainAccount[]>([]);
  const [blockchainUsers, setBlockchainUsers] = useState<BlockchainUser[]>([]);
  const [organizations, setOrganizations] = useState<string[]>(['org1', 'org2']);
  const [currentOrg, setCurrentOrg] = useState<string>('org1');
  const [loading, setLoading] = useState<boolean>(true);
  const [refreshing, setRefreshing] = useState<boolean>(false);
  const [initialLoaded, setInitialLoaded] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const clearError = () => setError(null);

  // Fetch avec gestion d'erreurs
  const fetchAPI = async (endpoint: string, options: RequestInit = {}) => {
    try {
      // Construire l'URL : /api + endpoint
      const cleanEndpoint = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
      let fullUrl = `${API_BASE_URL}${cleanEndpoint}`;

      // Ajouter org comme query param
      const separator = fullUrl.includes('?') ? '&' : '?';
      if (!fullUrl.includes('org=') && !endpoint.includes('organizations')) {
        fullUrl += `${separator}org=${currentOrg}`;
      }

      console.log(`[API] ${options.method || 'GET'} ${fullUrl}`);

      const response = await fetch(fullUrl, {
        headers: {
          'Content-Type': 'application/json',
          ...options.headers,
        },
        ...options,
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({ error: `HTTP ${response.status}` }));
        throw new Error(errorData.error || `HTTP ${response.status}`);
      }

      const data = await response.json();
      clearError();
      return data;
    } catch (err: any) {
      console.error(`[API Error] ${endpoint}:`, err.message);
      setError(err.message);
      throw err;
    }
  };

  // Rafraîchissement des stats du dashboard
  const refreshStats = async () => {
    try {
      const response = await fetchAPI('/dashboard');
      if (response.success && response.data) {
        const mappedStats: DashboardStats = {
          blocks: response.data.blocks || 1,
          transactions: response.data.transactions || 0,
          activePeers: response.data.activePeers || 0,
          activeOrderers: response.data.activeOrderers || 3,
          networkPerformance: response.data.networkPerformance || 0,
          avgTps: response.data.avgTps?.toString() || '0',
          maxTps: response.data.maxTps?.toString() || '0',
          totalAccounts: response.data.totalAccounts || 0,
          totalBalance: response.data.totalBalance || 0,
          organization: currentOrg,
          timestamp: response.data.timestamp || new Date().toISOString(),
        };
        setStats(mappedStats);
      }
    } catch (err) {
      console.error('Erreur lors du chargement des stats:', err);
      setError('Impossible de charger les statistiques');
    }
  };

  // Rafraîchissement des transactions
  const refreshTransactions = async (limit = 10) => {
    try {
      const response = await fetchAPI(`/transactions?limit=${limit}`);
      if (response.success && Array.isArray(response.data)) {
        const mappedTransactions = response.data.map((tx: any) => ({
          id: tx.id || tx.ID || '',
          from: tx.from || tx.From || 'system',
          to: tx.to || tx.To || 'system',
          amount: parseFloat(tx.amount || tx.Amount) || 0,
          block: parseInt(tx.block || tx.Block) || 0,
          timestamp: tx.timestamp || tx.Timestamp || new Date().toISOString(),
          status: tx.status || tx.Status || 'Confirmée',
        }));
        setTransactions(mappedTransactions);
      }
    } catch (err) {
      console.error('Erreur lors du chargement des transactions:', err);
      setTransactions([]);
    }
  };

  // Rafraîchissement des comptes
  const refreshAccounts = async () => {
    try {
      const response = await fetchAPI('/accounts');
      if (response.success && Array.isArray(response.data)) {
        const mappedAccounts = response.data.map((account: any) => ({
          id: account.id || account.ID || '',
          bank: account.bank || account.Bank || 'Banque Inconnue',
          currency: account.currency || account.Currency || 'MAD',
          type: account.type || account.Type || 'Standard',
          available: parseFloat(account.available || account.Available) || 0,
          blocked: account.blocked === true || account.Blocked === true,
        }));
        setAccounts(mappedAccounts);
      }
    } catch (err) {
      console.error('Erreur lors du chargement des comptes:', err);
      setAccounts([]);
    }
  };

  // Rafraîchissement des utilisateurs depuis le chaincode
  const refreshUsers = async () => {
    try {
      const response = await fetchAPI('/users');
      if (response.success && Array.isArray(response.data)) {
        const mappedUsers = response.data.map((user: any) => ({
          id: user.id || user.ID || '',
          name: user.name || user.Name || 'Unknown',
          email: user.email || user.Email || '',
          role: user.role || user.Role || 'User',
          active: user.active !== undefined ? user.active : (user.Active !== undefined ? user.Active : true),
        }));
        setBlockchainUsers(mappedUsers);
      }
    } catch (err) {
      console.error('Erreur lors du chargement des utilisateurs:', err);
      setBlockchainUsers([]);
    }
  };

  // Rafraîchissement complet
  const refreshAll = async () => {
    // Only show full loading spinner on first load
    if (!initialLoaded) {
      setLoading(true);
    } else {
      setRefreshing(true);
    }
    try {
      await Promise.all([
        refreshStats(),
        refreshTransactions(),
        refreshAccounts(),
        refreshUsers(),
      ]);
      if (!initialLoaded) {
        setInitialLoaded(true);
      }
    } catch (err: any) {
      console.error('Erreur lors du rafraîchissement complet:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  // Opérations blockchain
  const mintTokens = async (to: string, amount: number) => {
    try {
      if (!to || amount <= 0) {
        throw new Error('Paramètres invalides pour le mint');
      }
      const response = await fetchAPI('/mint', {
        method: 'POST',
        body: JSON.stringify({ to, amount, org: currentOrg }),
      });

      if (response.success) {
        await refreshTransactions();
        await refreshAccounts();
        clearError();
      }
    } catch (err: any) {
      console.error('Erreur lors du mint:', err);
      setError(err.message);
      throw err;
    }
  };

  const transferTokens = async (from: string, to: string, amount: number) => {
    try {
      if (!from || !to || amount <= 0) {
        throw new Error('Paramètres invalides pour le transfert');
      }
      const response = await fetchAPI('/transfer', {
        method: 'POST',
        body: JSON.stringify({ from, to, amount, org: currentOrg }),
      });

      if (response.success) {
        await refreshTransactions();
        await refreshAccounts();
        clearError();
      }
    } catch (err: any) {
      console.error('Erreur lors du transfert:', err);
      setError(err.message);
      throw err;
    }
  };

  const createAccount = async (accountId: string, bank: string, type: string) => {
    try {
      if (!accountId || !bank || !type) {
        throw new Error('Paramètres manquants pour créer un compte');
      }
      const response = await fetchAPI('/accounts/create', {
        method: 'POST',
        body: JSON.stringify({ accountId, bank, type, org: currentOrg }),
      });

      if (response.success) {
        await refreshAccounts();
        clearError();
      }
    } catch (err: any) {
      console.error('Erreur lors de la création du compte:', err);
      setError(err.message);
      throw err;
    }
  };

  const updateAccount = async (accountId: string, bank: string, currency: string, type: string, blocked: boolean) => {
    try {
      const response = await fetchAPI(`/accounts/${accountId}`, {
        method: 'PUT',
        body: JSON.stringify({ bank, currency, type, blocked, org: currentOrg }),
      });
      if (response.success) {
        await refreshAccounts();
        clearError();
      }
    } catch (err: any) {
      setError(err.message);
      throw err;
    }
  };

  const toggleAccountBlock = async (accountId: string) => {
    try {
      const response = await fetchAPI(`/accounts/${accountId}/toggle-block`, {
        method: 'PATCH',
        body: JSON.stringify({ org: currentOrg }),
      });
      if (response.success) {
        await refreshAccounts();
        clearError();
      }
    } catch (err: any) {
      setError(err.message);
      throw err;
    }
  };

  const createUser = async (userId: string, name: string, email: string, role: string) => {
    try {
      if (!userId || !name || !email || !role) {
        throw new Error('Tous les champs sont requis');
      }
      const response = await fetchAPI('/users/create', {
        method: 'POST',
        body: JSON.stringify({ userId, name, email, role, org: currentOrg }),
      });
      if (response.success) {
        await refreshUsers();
        clearError();
      }
    } catch (err: any) {
      setError(err.message);
      throw err;
    }
  };

  const updateUser = async (userId: string, name: string, email: string, role: string, active: boolean) => {
    try {
      const response = await fetchAPI(`/users/${userId}`, {
        method: 'PUT',
        body: JSON.stringify({ name, email, role, active, org: currentOrg }),
      });
      if (response.success) {
        await refreshUsers();
        clearError();
      }
    } catch (err: any) {
      setError(err.message);
      throw err;
    }
  };

  const toggleUserActive = async (userId: string) => {
    try {
      const response = await fetchAPI(`/users/${userId}/toggle`, {
        method: 'PATCH',
        body: JSON.stringify({ org: currentOrg }),
      });
      if (response.success) {
        await refreshUsers();
        clearError();
      }
    } catch (err: any) {
      setError(err.message);
      throw err;
    }
  };

  // Charger les organisations au démarrage
  useEffect(() => {
    const loadOrganizations = async () => {
      try {
        const response = await fetchAPI('/organizations');
        if (response.success && Array.isArray(response.data)) {
          setOrganizations(response.data);
        }
      } catch (err) {
        console.error('Erreur lors du chargement des organisations:', err);
        // Garder les organisations par défaut
      }
    };

    loadOrganizations();
  }, []);

  // Rafraîchissement au changement d'organisation
  useEffect(() => {
    setInitialLoaded(false);
    refreshAll();
  }, [currentOrg]);

  // Auto-refresh toutes les 30 secondes
  useEffect(() => {
    const interval = setInterval(refreshAll, 30000);
    return () => clearInterval(interval);
  }, [currentOrg]);

  const value: BlockchainContextType = {
    stats,
    transactions,
    accounts,
    blockchainUsers,
    organizations,
    currentOrg,
    loading,
    refreshing,
    error,

    refreshStats,
    refreshTransactions,
    refreshAccounts,
    refreshUsers,
    refreshAll,

    mintTokens,
    transferTokens,
    createAccount,
    updateAccount,
    toggleAccountBlock,
    createUser,
    updateUser,
    toggleUserActive,

    setCurrentOrg,
    clearError,
  };

  return (
    <BlockchainContext.Provider value={value}>
      {children}
    </BlockchainContext.Provider>
  );
};