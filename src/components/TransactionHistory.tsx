import React from "react";

const transactions = [
  {
    id: "7fb645b0c2a44310b23fd315bb1a15056f76e890530bf3e5a508a5437df0d",
    from: "acc_t994",
    to: "acc_t993",
    amount: 50.0,
    block: 3915,
    timestamp: "08/06/2025, 20:59:19",
  },
];

export default function TransactionHistory() {
  return (
    <div className="bg-white rounded-xl p-6 h-[420px] overflow-y-auto">
      <div className="text-[#FF6600] font-bold text-lg mb-4">Transaction History</div>
      <div className="flex gap-2 mb-4">
        <input className="border rounded px-2 py-1 w-60" placeholder="Search by ID, From, To" />
        <input className="border rounded px-2 py-1 w-32" placeholder="Min Amount" />
        <input className="border rounded px-2 py-1 w-32" placeholder="Max Amount" />
        <input className="border rounded px-2 py-1 w-36" type="date" />
        <input className="border rounded px-2 py-1 w-36" type="date" />
      </div>
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="bg-[#FF6600] text-white">
            <th className="p-2">Tx ID</th>
            <th>From</th>
            <th>To</th>
            <th>Amount</th>
            <th>Block</th>
            <th>Timestamp</th>
          </tr>
        </thead>
        <tbody>
          {transactions.map(tx => (
            <tr key={tx.id} className="odd:bg-gray-100 even:bg-white">
              <td className="p-2 truncate max-w-[150px]">{tx.id}</td>
              <td>{tx.from}</td>
              <td>{tx.to}</td>
              <td className="font-bold text-orange-600">{tx.amount.toFixed(2)}</td>
              <td>{tx.block}</td>
              <td>{tx.timestamp}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
