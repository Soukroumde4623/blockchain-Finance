import React, { useState } from "react";
import { useBlockchain, BlockchainAccount } from "../context/BlockchainContext";
import CreateAccountModal from "../components/CreateAccountModal";

interface NewAccountData {
  accountId: string;
  bank: string;
  type: string;
}

/* ─── Edit Account Modal ─── */
function EditAccountModal({
  open,
  account,
  onClose,
  onSave,
  isLoading,
}: {
  open: boolean;
  account: BlockchainAccount | null;
  onClose: () => void;
  onSave: (data: { accountId: string; bank: string; currency: string; type: string; blocked: boolean }) => void;
  isLoading: boolean;
}) {
  const [form, setForm] = useState({ bank: "", currency: "", type: "", blocked: false });

  React.useEffect(() => {
    if (account) {
      setForm({
        bank: account.bank,
        currency: account.currency,
        type: account.type,
        blocked: account.blocked ?? false,
      });
    }
  }, [account]);

  if (!open || !account) return null;

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/50 z-50">
      <div className="bg-[#232A3B] rounded-xl shadow-2xl px-8 py-7 w-full max-w-lg border border-[#2a3352]">
        <h2 className="text-xl font-bold text-[#FF8800] mb-5">Edit Account — #{account.id}</h2>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            onSave({ accountId: account.id, ...form });
          }}
        >
          <div className="flex flex-col gap-4 mb-6">
            <input
              placeholder="Bank"
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#FF8800]"
              value={form.bank}
              onChange={(e) => setForm({ ...form, bank: e.target.value })}
              required
            />
            <input
              placeholder="Currency"
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#FF8800]"
              value={form.currency}
              onChange={(e) => setForm({ ...form, currency: e.target.value })}
              required
            />
            <select
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-[#FF8800]"
              value={form.type}
              onChange={(e) => setForm({ ...form, type: e.target.value })}
            >
              <option value="Standard">Standard</option>
              <option value="Premium">Premium</option>
              <option value="Business">Business</option>
              <option value="Savings">Savings</option>
            </select>
            <label className="flex items-center gap-2 text-gray-300 cursor-pointer">
              <input
                type="checkbox"
                checked={form.blocked}
                onChange={(e) => setForm({ ...form, blocked: e.target.checked })}
                className="w-4 h-4 accent-[#FF4646]"
              />
              Blocked
            </label>
          </div>
          <div className="flex justify-end gap-3">
            <button
              type="submit"
              disabled={isLoading}
              className="bg-[#FF8800] hover:bg-[#e67600] disabled:opacity-50 text-white rounded px-6 py-2 font-medium transition"
            >
              {isLoading ? "Saving…" : "Save"}
            </button>
            <button
              type="button"
              className="bg-[#6b7280] hover:bg-[#555d68] text-white rounded px-6 py-2 font-medium transition"
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

/* ─── Account Page ─── */
export default function Account() {
  const {
    accounts,
    loading,
    error,
    createAccount,
    updateAccount,
    toggleAccountBlock,
    currentOrg,
    organizations,
    setCurrentOrg,
  } = useBlockchain();

  const [search, setSearch] = useState("");
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [editModalOpen, setEditModalOpen] = useState(false);
  const [selectedAccount, setSelectedAccount] = useState<BlockchainAccount | null>(null);
  const [isCreating, setIsCreating] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [togglingId, setTogglingId] = useState<string | null>(null);

  const filteredAccounts = accounts.filter(
    (acc) =>
      acc.id.toLowerCase().includes(search.toLowerCase()) ||
      acc.bank.toLowerCase().includes(search.toLowerCase())
  );

  const handleCreateAccount = async (newAccount: NewAccountData) => {
    setIsCreating(true);
    try {
      await createAccount(newAccount.accountId, newAccount.bank, newAccount.type);
      setCreateModalOpen(false);
    } catch (err) {
      alert("Erreur: " + (err as Error).message);
    } finally {
      setIsCreating(false);
    }
  };

  const handleEditAccount = async (data: {
    accountId: string;
    bank: string;
    currency: string;
    type: string;
    blocked: boolean;
  }) => {
    setIsEditing(true);
    try {
      await updateAccount(data.accountId, data.bank, data.currency, data.type, data.blocked);
      setEditModalOpen(false);
      setSelectedAccount(null);
    } catch (err) {
      alert("Erreur: " + (err as Error).message);
    } finally {
      setIsEditing(false);
    }
  };

  const handleToggleBlock = async (accountId: string) => {
    setTogglingId(accountId);
    try {
      await toggleAccountBlock(accountId);
    } catch (err) {
      alert("Erreur: " + (err as Error).message);
    } finally {
      setTogglingId(null);
    }
  };

  if (loading) return <p className="text-white text-center p-8">Chargement...</p>;
  if (error) return <p className="text-red-500 text-center p-8">Erreur : {error}</p>;

  return (
    <div className="bg-[#191E2D] rounded-xl p-6 min-h-screen overflow-y-auto text-white">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-bold text-[#14CB84]">Accounts</h2>
        <div className="flex gap-4">
          <select
            value={currentOrg}
            onChange={(e) => setCurrentOrg(e.target.value)}
            className="bg-[#232A3B] border border-[#14CB84] text-white px-3 py-2 rounded-lg"
          >
            {organizations.map((org) => (
              <option key={org} value={org}>
                {org.toUpperCase()}
              </option>
            ))}
          </select>
          <button
            className="bg-[#FF8800] px-5 py-2 rounded font-semibold text-white hover:bg-[#e67600] transition"
            onClick={() => setCreateModalOpen(true)}
          >
            + New Account
          </button>
        </div>
      </div>

      <input
        type="search"
        placeholder="Search by account number or bank…"
        className="w-full md:w-96 rounded border border-[#2a3352] bg-[#101828] px-4 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#FF8800] mb-6"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredAccounts.length === 0 ? (
          <p className="text-gray-400 col-span-3 text-center py-10">No accounts found.</p>
        ) : (
          filteredAccounts.map((acc) => (
            <div
              key={acc.id}
              className={`bg-[#232A3B] border rounded-xl p-5 flex flex-col shadow-sm hover:shadow-lg transition ${
                acc.blocked ? "border-red-500/60" : "border-[#2a3352]"
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[#FF6600] font-bold text-xl truncate">#{acc.id}</span>
                {acc.blocked && (
                  <span className="text-xs bg-red-500/20 text-red-400 font-semibold px-2 py-0.5 rounded">
                    BLOCKED
                  </span>
                )}
              </div>
              <div className="text-gray-300 mb-1 text-sm">
                <strong>Bank:</strong> {acc.bank}
              </div>
              <div className="text-gray-300 mb-1 text-sm">
                <strong>Currency:</strong> {acc.currency}
              </div>
              <div className="text-gray-300 mb-3 text-sm">
                <strong>Type:</strong> {acc.type}
              </div>
              <div className="mb-4 mt-auto text-green-400 font-semibold text-lg">
                Available: {acc.available.toLocaleString("fr-FR", { style: "currency", currency: "MAD" })}
              </div>
              <div className="flex gap-3">
                <button
                  className="flex-1 bg-[#FF8800] px-3 py-2 rounded hover:bg-[#e67600] transition font-medium text-sm"
                  onClick={() => {
                    setSelectedAccount(acc);
                    setEditModalOpen(true);
                  }}
                >
                  Edit
                </button>
                <button
                  disabled={togglingId === acc.id}
                  className={`flex-1 px-3 py-2 rounded transition font-medium text-sm disabled:opacity-50 ${
                    acc.blocked
                      ? "bg-[#14CB84] hover:bg-[#10ab6e]"
                      : "bg-[#FF4646] hover:bg-[#d23333]"
                  }`}
                  onClick={() => handleToggleBlock(acc.id)}
                >
                  {togglingId === acc.id ? "…" : acc.blocked ? "Unblock" : "Block"}
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Modals */}
      <CreateAccountModal
        open={createModalOpen}
        onClose={() => setCreateModalOpen(false)}
        onCreate={handleCreateAccount}
        isLoading={isCreating}
      />
      <EditAccountModal
        open={editModalOpen}
        account={selectedAccount}
        onClose={() => {
          setEditModalOpen(false);
          setSelectedAccount(null);
        }}
        onSave={handleEditAccount}
        isLoading={isEditing}
      />
    </div>
  );
}