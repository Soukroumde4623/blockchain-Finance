import StatCard from "../components/StatCard";
import CircularGauge from "../components/CircularGauge";
import TransactionTable from "../components/TransactionTable";
import TpsPerPeerChart from "../components/TpsPerPeerChart";
import { useBlockchain } from "../context/BlockchainContext";

import { IconDatabase, IconFileText, IconUsers, IconServer } from '@tabler/icons-react';

export default function Dashboard() {
  const { stats, transactions, loading, error, currentOrg, organizations, setCurrentOrg } = useBlockchain();

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center text-white">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#14CB84] mx-auto mb-4"></div>
          <p>Chargement des données blockchain...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return <p className="text-red-500 text-center p-8">Erreur : {error}</p>;
  }

  if (!stats) {
    return <p className="text-white text-center p-8">Aucune donnée disponible</p>;
  }

  // Stats adaptées aux données du backend
  const statsData = [
    {
      label: "Blocks",
      value: stats.blocks || 0,
      positive: true,
      icon: <IconDatabase size={30} color="#970d0dff" />,
    },
    {
      label: "Total TXs",
      value: stats.transactions || 0,
      icon: <IconFileText size={30} color="#970d0dff" />,
    },
    {
      label: "Active Peers",
      value: stats.activePeers || 0,
      positive: true,
      icon: <IconUsers size={30} color="#970d0dff" />,
    },
    {
      label: "Active Orderers",
      value: stats.activeOrderers || 0,
      icon: <IconServer size={30} color="#970d0dff" />,
    },
  ];

  const networkPerformancePercent = stats.networkPerformance || 75.55;
  const recentTransactions = transactions.slice(0, 10);

  return (
    <div className="space-y-6">
        {/* Sélecteur d'organisation */}
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-3xl font-bold">Dashboard</h1>
          <select
            value={currentOrg}
            onChange={(e) => setCurrentOrg(e.target.value)}
            className="bg-[#232A3B] border border-[#14CB84] text-white px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#14CB84]"
          >
            {organizations.map((org) => (
              <option key={org} value={org}>
                {org.toUpperCase()}
              </option>
            ))}
          </select>
        </div>

        {/* Première ligne : 4 cards statistiques */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {statsData.map((stat, i) => (
            <StatCard key={i} {...stat} />
          ))}
        </div>

        {/* Deuxième ligne : Network Performance + Chart */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="bg-[#191E2D] rounded-xl p-6 flex flex-col items-center justify-center">
            <span className="font-bold text-lg mb-2">NETWORK PERFORMANCE</span>
            <CircularGauge percent={networkPerformancePercent} />
            <div className="text-center mt-2 text-sm text-gray-400">
              Le canal est utilisé à {networkPerformancePercent.toFixed(2)}%
            </div>
            <div className="flex justify-between w-full mt-4 text-xs text-gray-300">
              <div className="flex-1 text-center">
                UTILISATEURS<br />
                <span className="text-red-400 font-bold">{stats.users || 20}</span>
              </div>
              <div className="flex-1 text-center">
                AVG TPS<br />
                <span className="text-green-400 font-bold">{stats.avgTps || '0'}</span>
              </div>
              <div className="flex-1 text-center">
                MAX TPS<br />
                <span className="text-green-400 font-bold">{stats.maxTps || '0'}</span>
              </div>
            </div>
          </div>

          <div className="bg-[#191E2D] rounded-xl p-6">
            <TpsPerPeerChart transactions={recentTransactions} />
          </div>
        </div>

        {/* Bloc historique transactions */}
        <div className="bg-[#191E2D] rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <span className="font-bold text-lg">Transaction History</span>
            <div className="space-x-2">
              <button className="bg-[#232A3B] px-4 py-2 rounded text-sm hover:bg-[#2a334f] transition">
                Filter
              </button>
              <button className="bg-[#14CB84] px-4 py-2 rounded text-sm hover:bg-[#10ab6e] transition">
                See all
              </button>
            </div>
          </div>
          <TransactionTable transactions={recentTransactions} />
        </div>
    </div>
  );
}