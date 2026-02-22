import React from 'react';

interface Transaction {
  id: string;
  from: string;
  to: string;
  amount: number;
  block: number;
  timestamp: string;
}

interface TransactionTableProps {
  transactions: Transaction[];
}

const TransactionTable: React.FC<TransactionTableProps> = ({ transactions }) => {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left bg-[#232A3B] rounded-xl overflow-hidden">
        <thead>
          <tr className="text-[#14CB84] bg-[#232A3B]">
            <th className="py-3 px-4 font-semibold">Tx ID</th>
            <th className="py-3 px-4 font-semibold">From</th>
            <th className="py-3 px-4 font-semibold">To</th>
            <th className="py-3 px-4 font-semibold">Amount</th>
            <th className="py-3 px-4 font-semibold">Block</th>
            <th className="py-3 px-4 font-semibold">Timestamp</th>
          </tr>
        </thead>
        <tbody>
          {transactions.length === 0 ? (
            <tr><td colSpan={6} className="text-center text-gray-400 py-10">No transactions found.</td></tr>
          ) : (
            transactions.map((tx, index) => (
              <tr key={tx.id} className={`${index % 2 === 0 ? 'bg-[#1A2235]' : 'bg-[#232A3B]'} hover:bg-[#2a334f] transition`}>
                <td className="px-4 py-3 truncate max-w-[200px]" title={tx.id}>{tx.id}</td>
                <td className="px-4 py-3">{tx.from}</td>
                <td className="px-4 py-3">{tx.to}</td>
                <td className="px-4 py-3 font-semibold text-green-400">{tx.amount.toFixed(2)}</td>
                <td className="px-4 py-3">{tx.block}</td>
                <td className="px-4 py-3">{tx.timestamp}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
};

export default TransactionTable;