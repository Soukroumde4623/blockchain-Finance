import React from "react";

const rules = [
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
  // ... (autres règles ici)
];

export default function AuthorizationRules() {
  return (
    <div className="bg-white rounded-xl p-6 min-h-[500px] overflow-y-auto">
      <div className="flex items-center justify-between mb-3">
        <span className="text-[#FF6600] font-bold text-xl">Authorization Rules</span>
        <button className="bg-[#FF6600] text-white px-4 py-1 rounded font-semibold">+ Add Authorization</button>
      </div>
      <input
        className="border border-gray-300 rounded px-3 py-2 w-full mb-5"
        placeholder="Search by name, transaction or account type…"
      />
      <div className="grid grid-cols-3 gap-4">
        {rules.map(rule => (
          <div key={rule.id} className="border border-gray-300 rounded-xl p-4 shadow-sm">
            <div className="font-bold text-[#ff6600] mb-1">{rule.title}</div>
            <div className="text-gray-700 text-[15px]">ID: {rule.id}</div>
            <div className="text-gray-700 text-[15px]">Transaction: {rule.transaction}</div>
            <div className="text-gray-700 text-[15px]">Account: {rule.account}</div>
            <div className="text-gray-700 text-[15px]">Rules: {rule.rules}</div>
            <div className="mt-2">
              Active:{" "}
              {rule.active ? (
                <span className="inline-block align-middle text-green-600 text-lg">✅</span>
              ) : (
                <span className="inline-block align-middle text-red-600 text-lg">❌</span>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
