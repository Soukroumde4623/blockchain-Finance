import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:4000/api';

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
}

export interface BlockchainUser {
  id: string;
  name: string;
  email: string;
  role: string;
  active: boolean;
}

export interface TransferRequest {
  from: string;
  to: string;
  amount: number;
  org?: string;
}

export interface CreateAccountRequest {
  accountId: string;
  bank: string;
  type: string;
  org?: string;
}

export interface MintRequest {
  to: string;
  amount: number;
  org?: string;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  timestamp?: string;
  organization?: string;
}

class BlockchainAPI {
  private getApiUrl = (): string => {
    if (typeof import.meta !== 'undefined' && import.meta.env) {
      return (import.meta.env.VITE_API_URL as string) || 'http://localhost:4000/api';
    }
    return 'http://localhost:4000/api';
  };

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    try {
      const url = new URL(endpoint, this.getApiUrl());
      const response = await fetch(url.toString(), {
        headers: {
          'Content-Type': 'application/json',
          ...options.headers,
        },
        ...options,
      });

      if (!response.ok) {
        const error = await response.json().catch(() => ({ 
          error: `HTTP ${response.status}` 
        }));
        throw new Error(error.error || `HTTP ${response.status}`);
      }

      return await response.json();
    } catch (error: any) {
      console.error(`API Error: ${endpoint}`, error);
      return {
        success: false,
        error: error.message,
      };
    }
  }

  // ==================== DASHBOARD ====================
  async getDashboardStats(org = 'org1'): Promise<ApiResponse<DashboardStats>> {
    return this.request(`/dashboard?org=${org}`);
  }

  // ==================== TRANSACTIONS ====================
  async getTransactions(org = 'org1', limit = 10): Promise<ApiResponse<Transaction[]>> {
    return this.request(`/transactions?org=${org}&limit=${limit}`);
  }

  async mintTokens(
    to: string,
    amount: number,
    org = 'org1'
  ): Promise<ApiResponse<any>> {
    return this.request('/mint', {
      method: 'POST',
      body: JSON.stringify({ to, amount, org }),
    });
  }

  async transferTokens(
    from: string,
    to: string,
    amount: number,
    org = 'org1'
  ): Promise<ApiResponse<any>> {
    return this.request('/transfer', {
      method: 'POST',
      body: JSON.stringify({ from, to, amount, org }),
    });
  }

  // ==================== ACCOUNTS ====================
  async getAccounts(org = 'org1'): Promise<ApiResponse<BlockchainAccount[]>> {
    return this.request(`/accounts?org=${org}`);
  }

  async getAccountBalance(
    accountId: string,
    org = 'org1'
  ): Promise<ApiResponse<{ accountId: string; balance: number }>> {
    return this.request(`/accounts/${accountId}/balance?org=${org}`);
  }

  async createAccount(
    accountId: string,
    bank: string,
    type: string,
    org = 'org1'
  ): Promise<ApiResponse<any>> {
    return this.request('/accounts/create', {
      method: 'POST',
      body: JSON.stringify({ accountId, bank, type, org }),
    });
  }

  // ==================== ORGANIZATIONS ====================
  async getOrganizations(): Promise<ApiResponse<string[]>> {
    return this.request('/organizations');
  }

  // ==================== USERS ====================
  async getUsers(org = 'org1'): Promise<ApiResponse<BlockchainUser[]>> {
    return this.request(`/users?org=${org}`);
  }

  async createUser(
    userId: string,
    name: string,
    email: string,
    role: string,
    org = 'org1'
  ): Promise<ApiResponse<any>> {
    return this.request('/users/create', {
      method: 'POST',
      body: JSON.stringify({ userId, name, email, role, org }),
    });
  }

  // ==================== HEALTH ====================
  async health(org = 'org1'): Promise<ApiResponse<any>> {
    return this.request(`/health?org=${org}`);
  }

  // ==================== FUNCTIONS ====================
  async detectFunctions(org = 'org1'): Promise<ApiResponse<any[]>> {
    return this.request(`/functions?org=${org}`);
  }

  // ==================== GENERIC CALL ====================
  async callFunction(
    functionName: string,
    args: string[] = [],
    isQuery = true,
    org = 'org1'
  ): Promise<ApiResponse<any>> {
    return this.request('/call', {
      method: 'POST',
      body: JSON.stringify({ functionName, args, isQuery, org }),
    });
  }
}

export const blockchainAPI = new BlockchainAPI();