import React from "react";

const accounts = [
  { id: "ACC001", bank: "BNK001", currency: "MAD", type: "Checking", available: 950 },
  { id: "ACC002", bank: "BNK002", currency: "MAD", type: "Savings", available: 1980 },
  { id: "ACC003", bank: "BNK001", currency: "MAD", type: "Business", available: 4750 },
  { id: "ACC004", bank: "BNK004", currency: "MAD", type: "Checking", available: 1400 },
  { id: "ACC005", bank: "BNK003", currency: "MAD", type: "Savings", available: 2900 },
  { id: "ACC006", bank: "BNK004", currency: "MAD", type: "Business", available: 750 },
];

export default function AccountManagement() {
  return (
    <div className="bg-[#FFF5ED] rounded-xl p-6 min-h-[500px] overflow-y-auto">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          {/* Icône compte */}
          <span className="text-2xl">🏦</span>
          <span className="text-[#C05818] font-bold text-2xl">Account Management</span>
        </div>
        <button className="bg-[#FF8800] text-white px-4 py-2 rounded font-semibold">+ New Account</button>
      </div>
      <input
        className="border border-gray-300 rounded px-3 py-2 w-96 mb-5"
        placeholder="Search account number..."
      />
      <div className="grid grid-cols-3 gap-4">
        {accounts.map(acc => (
          <div key={acc.id} className="bg-white border border-gray-300 rounded-xl p-4 shadow-sm flex flex-col">
            <div className="text-[#FF6600] font-bold text-lg mb-1">#{acc.id}</div>
            <div className="text-gray-700 text-[15px] mb-1">Bank: {acc.bank}</div>
            <div className="text-gray-700 text-[15px] mb-1">Currency: {acc.currency}</div>
            <div className="text-gray-700 text-[15px] mb-1">Type: {acc.type}</div>
            <div className="text-[15px] mb-3 text-green-600 font-bold">
              Available: {acc.available.toLocaleString(undefined, { style: 'currency', currency: 'USD' }).replace('$','MAD ')}
            </div>
            <div className="flex gap-2 mt-auto">
              <button className="bg-[#FF8800] text-white px-4 py-1 rounded">Edit</button>
              <button className="bg-[#FF4646] text-white px-4 py-1 rounded">Block</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
