import React, { useState } from "react";

export default function AddAuthorizationModal({ onClose, onCreate }) {
  const [rules, setRules] = useState([""]);
  const [active, setActive] = useState(true);

  const addRule = () => setRules([...rules, ""]);
  const updateRule = (idx, val) =>
    setRules(rules.map((rule, i) => (i === idx ? val : rule)));

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-20 z-50">
      <div className="bg-white rounded-2xl shadow-lg w-[475px] p-8">
        <h2 className="text-[#FF6600] font-bold text-3xl mb-6">Add Authorization</h2>
        <form className="space-y-3">
          <input className="border rounded px-3 py-2 w-full" placeholder="ID" />
          <input className="border rounded px-3 py-2 w-full" placeholder="Name" />
          <input className="border rounded px-3 py-2 w-full" placeholder="Transaction Type" />
          <input className="border rounded px-3 py-2 w-full" placeholder="Account Type" />
          <div className="mt-2 mb-1 font-bold text-[#AA5522]">Rules:</div>
          {rules.map((rule, idx) => (
            <input
              key={idx}
              className="border rounded px-3 py-2 w-full mb-1"
              placeholder={`Rule ${idx + 1}`}
              value={rule}
              onChange={e => updateRule(idx, e.target.value)}
            />
          ))}
          <button type="button" onClick={addRule} className="text-[#FF6600] text-sm mb-2">
            + Add Rule
          </button>
          <div className="flex items-center gap-2 mb-2">
            <input
              type="checkbox"
              checked={active}
              onChange={e => setActive(e.target.checked)}
              id="active"
              className="w-4 h-4 accent-[#2186f5]"
            />
            <label htmlFor="active" className="text-gray-700">Active</label>
          </div>
          <div className="flex justify-end space-x-3 mt-4">
            <button
              type="button"
              className="border border-gray-400 px-5 py-2 rounded text-gray-700"
              onClick={onClose}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="bg-[#FF6600] text-white px-5 py-2 rounded"
              onClick={e => {
                e.preventDefault();
                onCreate && onCreate({ /* …données formulaire… */ });
              }}
            >
              Create
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
