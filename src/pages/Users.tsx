import React, { useState } from "react";
import { useBlockchain, BlockchainUser } from "../context/BlockchainContext";

/* ─── Create User Modal ─── */
function CreateUserModal({
  open,
  onClose,
  onCreate,
  isLoading,
}: {
  open: boolean;
  onClose: () => void;
  onCreate: (data: { userId: string; name: string; email: string; role: string }) => void;
  isLoading: boolean;
}) {
  const [form, setForm] = useState({ userId: "", name: "", email: "", role: "user" });
  if (!open) return null;

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/50 z-50">
      <div className="bg-[#232A3B] rounded-xl shadow-2xl px-8 py-7 w-full max-w-lg border border-[#2a3352]">
        <h2 className="text-xl font-bold text-[#14CB84] mb-5">Create New User</h2>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            onCreate(form);
          }}
        >
          <div className="flex flex-col gap-4 mb-6">
            <input
              placeholder="User ID"
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#14CB84]"
              value={form.userId}
              onChange={(e) => setForm({ ...form, userId: e.target.value })}
              required
            />
            <input
              placeholder="Full Name"
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#14CB84]"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              required
            />
            <input
              type="email"
              placeholder="Email"
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#14CB84]"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
              required
            />
            <select
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-[#14CB84]"
              value={form.role}
              onChange={(e) => setForm({ ...form, role: e.target.value })}
            >
              <option value="admin">Admin</option>
              <option value="user">User</option>
              <option value="auditor">Auditor</option>
            </select>
          </div>
          <div className="flex justify-end gap-3">
            <button
              type="submit"
              disabled={isLoading}
              className="bg-[#14CB84] hover:bg-[#10ab6e] disabled:opacity-50 text-white rounded px-6 py-2 font-medium transition"
            >
              {isLoading ? "Creating…" : "Create"}
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

/* ─── Edit User Modal ─── */
function EditUserModal({
  open,
  user,
  onClose,
  onSave,
  isLoading,
}: {
  open: boolean;
  user: BlockchainUser | null;
  onClose: () => void;
  onSave: (data: { userId: string; name: string; email: string; role: string; active: boolean }) => void;
  isLoading: boolean;
}) {
  const [form, setForm] = useState({ name: "", email: "", role: "", active: true });

  React.useEffect(() => {
    if (user) {
      setForm({ name: user.name, email: user.email, role: user.role, active: user.active });
    }
  }, [user]);

  if (!open || !user) return null;

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/50 z-50">
      <div className="bg-[#232A3B] rounded-xl shadow-2xl px-8 py-7 w-full max-w-lg border border-[#2a3352]">
        <h2 className="text-xl font-bold text-[#FF8800] mb-5">Edit User — {user.id}</h2>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            onSave({ userId: user.id, ...form });
          }}
        >
          <div className="flex flex-col gap-4 mb-6">
            <input
              placeholder="Full Name"
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#FF8800]"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              required
            />
            <input
              type="email"
              placeholder="Email"
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#FF8800]"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
              required
            />
            <select
              className="border border-[#2a3352] bg-[#101828] rounded px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-[#FF8800]"
              value={form.role}
              onChange={(e) => setForm({ ...form, role: e.target.value })}
            >
              <option value="admin">Admin</option>
              <option value="user">User</option>
              <option value="auditor">Auditor</option>
            </select>
            <label className="flex items-center gap-2 text-gray-300 cursor-pointer">
              <input
                type="checkbox"
                checked={form.active}
                onChange={(e) => setForm({ ...form, active: e.target.checked })}
                className="w-4 h-4 accent-[#14CB84]"
              />
              Active
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

/* ─── Users Page ─── */
export default function Users() {
  const {
    blockchainUsers,
    loading,
    error,
    currentOrg,
    organizations,
    setCurrentOrg,
    createUser,
    updateUser,
    toggleUserActive,
  } = useBlockchain();

  const [search, setSearch] = useState("");
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [editModalOpen, setEditModalOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<BlockchainUser | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [togglingId, setTogglingId] = useState<string | null>(null);

  const filtered = blockchainUsers.filter(
    (u) =>
      u.id.toLowerCase().includes(search.toLowerCase()) ||
      u.name.toLowerCase().includes(search.toLowerCase()) ||
      u.email.toLowerCase().includes(search.toLowerCase())
  );

  const handleCreate = async (data: { userId: string; name: string; email: string; role: string }) => {
    setActionLoading(true);
    try {
      await createUser(data.userId, data.name, data.email, data.role);
      setCreateModalOpen(false);
    } catch (err) {
      alert("Erreur: " + (err as Error).message);
    } finally {
      setActionLoading(false);
    }
  };

  const handleEdit = async (data: { userId: string; name: string; email: string; role: string; active: boolean }) => {
    setActionLoading(true);
    try {
      await updateUser(data.userId, data.name, data.email, data.role, data.active);
      setEditModalOpen(false);
      setSelectedUser(null);
    } catch (err) {
      alert("Erreur: " + (err as Error).message);
    } finally {
      setActionLoading(false);
    }
  };

  const handleToggle = async (userId: string) => {
    setTogglingId(userId);
    try {
      await toggleUserActive(userId);
    } catch (err) {
      alert("Erreur: " + (err as Error).message);
    } finally {
      setTogglingId(null);
    }
  };

  if (loading) return <p className="text-center text-white p-8">Chargement...</p>;
  if (error) return <p className="text-red-500 text-center p-8">Erreur : {error}</p>;

  return (
    <div className="bg-[#191E2D] rounded-xl p-6 min-h-screen overflow-y-auto text-white">
      <div className="flex items-center justify-between mb-6">
        <span className="text-[#14CB84] font-bold text-2xl">User Management</span>
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
            className="bg-[#14CB84] hover:bg-[#10ab6e] transition text-white px-4 py-2 rounded font-semibold"
            onClick={() => setCreateModalOpen(true)}
          >
            + Add User
          </button>
        </div>
      </div>

      <input
        type="search"
        placeholder="Search by name, email, or ID…"
        className="w-full rounded border border-[#2a3352] bg-[#101828] px-4 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#14CB84] mb-6"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />

      <div className="overflow-x-auto">
        <table className="w-full text-left bg-[#232A3B] rounded-xl overflow-hidden">
          <thead>
            <tr className="text-[#14CB84] bg-[#232A3B] border-b border-[#2a3352]">
              <th className="py-4 px-4 font-semibold">ID</th>
              <th className="py-4 px-4 font-semibold">Name</th>
              <th className="py-4 px-4 font-semibold">Email</th>
              <th className="py-4 px-4 font-semibold">Role</th>
              <th className="py-4 px-4 font-semibold">Status</th>
              <th className="py-4 px-4 font-semibold text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={6} className="text-center text-gray-400 py-10">
                  No users found.
                </td>
              </tr>
            ) : (
              filtered.map((user) => (
                <tr
                  key={user.id}
                  className="odd:bg-[#1A2235] even:bg-[#232A3B] transition border-b border-[#2a3352] hover:bg-[#2a334f]"
                >
                  <td className="px-4 py-4">{user.id}</td>
                  <td className="px-4 py-4">{user.name}</td>
                  <td className="px-4 py-4">{user.email}</td>
                  <td className="px-4 py-4">
                    <span className="bg-[#14CB84]/20 text-[#14CB84] text-xs font-semibold px-2 py-1 rounded">
                      {user.role}
                    </span>
                  </td>
                  <td className="px-4 py-4">
                    {user.active ? (
                      <span className="text-green-400 font-semibold flex items-center gap-1">
                        <span className="w-2 h-2 rounded-full bg-green-400 inline-block" /> Active
                      </span>
                    ) : (
                      <span className="text-red-400 font-semibold flex items-center gap-1">
                        <span className="w-2 h-2 rounded-full bg-red-400 inline-block" /> Inactive
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-4 text-right">
                    <div className="flex gap-2 justify-end">
                      <button
                        className="bg-[#FF8800] hover:bg-[#e67600] text-white px-3 py-1 rounded text-sm transition"
                        onClick={() => {
                          setSelectedUser(user);
                          setEditModalOpen(true);
                        }}
                      >
                        Edit
                      </button>
                      <button
                        disabled={togglingId === user.id}
                        className={`${
                          user.active
                            ? "bg-[#FF4646] hover:bg-[#d23333]"
                            : "bg-[#14CB84] hover:bg-[#10ab6e]"
                        } disabled:opacity-50 text-white px-3 py-1 rounded text-sm transition`}
                        onClick={() => handleToggle(user.id)}
                      >
                        {togglingId === user.id
                          ? "…"
                          : user.active
                          ? "Deactivate"
                          : "Activate"}
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Modals */}
      <CreateUserModal
        open={createModalOpen}
        onClose={() => setCreateModalOpen(false)}
        onCreate={handleCreate}
        isLoading={actionLoading}
      />
      <EditUserModal
        open={editModalOpen}
        user={selectedUser}
        onClose={() => {
          setEditModalOpen(false);
          setSelectedUser(null);
        }}
        onSave={handleEdit}
        isLoading={actionLoading}
      />
    </div>
  );
}
