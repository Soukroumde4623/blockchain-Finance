import React, { useState } from "react";

interface CreateAccountModalProps {
  open: boolean;
  onClose: () => void;
  onCreate: (account: { accountId: string; bank: string; type: string }) => void;
  isLoading?: boolean;
}

export default function CreateAccountModal({ open, onClose, onCreate, isLoading }: CreateAccountModalProps) {
  const [form, setForm] = useState({
    accountId: "",
    bank: "",
    type: "",
  });

  if (!open) return null;

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-30 z-50">
      <div className="bg-white rounded-lg shadow px-8 py-7 w-full max-w-2xl">
        <h2 className="text-[1.5rem] font-bold text-[#232A3B] mb-4">
          Create New Account
        </h2>
        <form
          onSubmit={e => {
            e.preventDefault();
            onCreate(form);
            setForm({ accountId: "", bank: "", type: "" });
          }}
        >
          <div className="grid grid-cols-2 gap-x-4 gap-y-3 mb-6">
            <div className="flex flex-col">
              <input
                id="accountNumber"
                type="text"
                placeholder="Account Number"
                className="border border-gray-400 rounded px-3 py-2 w-full focus:outline-none text-[#232A3B]"
                value={form.accountId}
                onChange={e => setForm({ ...form, accountId: e.target.value })}
                required
              />
            </div>
            <div className="flex flex-col">
              <input
                id="bankNumber"
                type="text"
                placeholder="Bank Number"
                className="border border-gray-400 rounded px-3 py-2 w-full focus:outline-none text-[#232A3B]"
                value={form.bank}
                onChange={e => setForm({ ...form, bank: e.target.value })}
                required
              />
            </div>
            <div className="flex flex-col">
              <input
                id="accountType"
                type="text"
                placeholder="Account Type"
                className="border border-gray-400 rounded px-3 py-2 w-full focus:outline-none text-[#232A3B]"
                value={form.type}
                onChange={e => setForm({ ...form, type: e.target.value })}
                required
              />
            </div>
          </div>
          <div className="flex justify-end items-center gap-3 pt-2">
            <button
              type="submit"
              disabled={isLoading}
              className="bg-[#F4511E] text-white rounded px-6 py-2 font-medium hover:bg-[#cc4217] transition disabled:opacity-50"
            >
              {isLoading ? "Creating…" : "Create"}
            </button>
            <button
              type="button"
              className="bg-[#949DA8] text-white rounded px-6 py-2 font-medium hover:bg-[#7e8995] transition"
              onClick={onClose}
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}