import React from 'react';

const authorizations = [
  {
    title: 'Salary Credit',
    desc: 'Transactions: Credit',
    account: 'Account: Savings',
    rules: 'Rule: MaxAmount: 1000, Country: AA',
    active: true,
  },
    {
    title: 'Salary Credit',
    desc: 'Transactions: Credit',
    account: 'Account: Savings',
    rules: 'Rule: MaxAmount: 1000, Country: AA',
    active: true,
  },
];

export default function AuthorizationRules() {
  return (
  
      <main className="flex-1 p-8">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-white text-3xl font-bold">Authorization Rules</h1>
          <button className="bg-[#14CB84] hover:bg-[#12b072] text-white px-5 py-2 rounded font-semibold">
            + Add Authorization
          </button>
        </div>
        <input
          type="text"
          placeholder="Search by name, transaction or account type..."
          className="w-full p-3 rounded bg-[#181F36] text-white mb-6 border border-gray-700"
        />
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {authorizations.map((item, idx) => (
            <div key={idx} className="bg-[#181F36] rounded-xl p-5 shadow-lg border border-gray-800">
              <h2 className="text-[#14CB84] text-xl font-bold mb-2">{item.title}</h2>
              <div className="text-gray-300">{item.desc}</div>
              <div className="text-gray-400">{item.account}</div>
              <div className="font-mono text-gray-400 text-sm">{item.rules}</div>
              {item.active && (
                <span className="bg-[#14CB84] text-white px-3 py-1 rounded mt-3 inline-block text-xs font-bold">
                  Active
                </span>
              )}
            </div>
          ))}
        </div>
      </main>
    
  );
}
