import React, { useState } from "react";

const rulesData = [
  {
    id: 1,
    title: "Salary Credit",
    transaction: "Credit",
    account: "Savings",
    rules: "MaxAmount:10000, Country:MA",
    active: true,
  },
  {
    id: 2,
    title: "Bill Payment",
    transaction: "Debit",
    account: "Current",
    rules: "Limit:2000, Time:9AM-5PM",
    active: true,
  },
  // ... autres règles ici ...
];

export default function AuthorizationRules() {
  const [search, setSearch] = useState("");

  const filteredRules = rulesData.filter(({ title, transaction, account }) => {
    const toSearch = `${title} ${transaction} ${account}`.toLowerCase();
    return toSearch.includes(search.toLowerCase());
  });

  return (
    <div className="bg-[#191E2D] rounded-xl p-6 min-h-[500px] overflow-y-auto text-white">
      <div className="flex items-center justify-between mb-5">
        <span className="text-[#FF6600] font-bold text-xl">Authorization Rules</span>
        <button className="bg-[#FF6600] px-4 py-1 rounded font-semibold hover:bg-[#cc5200] transition">
          + Add Authorization
        </button>
      </div>
      
      <input
        type="search"
        aria-label="Search authorizations"
        placeholder="Search by name, transaction or account type…"
        className="w-full rounded border border-[#2a3352] bg-[#101828] px-4 py-2 mb-6 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#FF6600]"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />
      
      {filteredRules.length === 0 ? (
        <div className="text-gray-500 text-center">No matching authorization rules found.</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {filteredRules.map((rule) => (
            <div
              key={rule.id}
              className="border border-[#2a3352] rounded-xl p-4 shadow-sm bg-[#232A3B]"
            >
              <div className="font-bold text-[#FF6600] mb-2 text-lg">{rule.title}</div>
              <div className="text-gray-300 text-sm mb-1">ID: {rule.id}</div>
              <div className="text-gray-300 text-sm mb-1">Transaction: {rule.transaction}</div>
              <div className="text-gray-300 text-sm mb-1">Account: {rule.account}</div>
              <div className="text-gray-300 text-sm mb-2">Rules: {rule.rules}</div>
              <div>
                Active:{" "}
                {rule.active ? (
                  <span className="inline-block align-middle text-green-500 text-lg">✅</span>
                ) : (
                  <span className="inline-block align-middle text-red-600 text-lg">❌</span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
