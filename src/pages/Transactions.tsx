import React, { useState } from "react";
import { useBlockchain } from "../context/BlockchainContext";
import TransactionTable from "../components/TransactionTable";

export default function Transactions() {
  const { transactions, loading, error, mintTokens, transferTokens, currentOrg, organizations, setCurrentOrg } = useBlockchain();
  const [search, setSearch] = useState("");
  const [mintTo, setMintTo] = useState("");
  const [mintAmount, setMintAmount] = useState("");
  const [transferFrom, setTransferFrom] = useState("");
  const [transferTo, setTransferTo] = useState("");
  const [transferAmount, setTransferAmount] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [successMessage, setSuccessMessage] = useState("");

  const filtered = transactions.filter(
    (tx) =>
      tx.id.toLowerCase().includes(search.toLowerCase()) ||
      tx.from.toLowerCase().includes(search.toLowerCase()) ||
      tx.to.toLowerCase().includes(search.toLowerCase())
  );

  const handleMint = async () => {
    if (!mintTo || !mintAmount) {
      alert("Veuillez remplir tous les champs");
      return;
    }
    setIsLoading(true);
    try {
      await mintTokens(mintTo, parseFloat(mintAmount));
      setSuccessMessage("Mint effectué avec succès !");
      setMintTo("");
      setMintAmount("");
      setTimeout(() => setSuccessMessage(""), 3000);
    } catch (err) {
      alert("Erreur lors du mint: " + (err as Error).message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleTransfer = async () => {
    if (!transferFrom || !transferTo || !transferAmount) {
      alert("Veuillez remplir tous les champs");
      return;
    }
    setIsLoading(true);
    try {
      await transferTokens(transferFrom, transferTo, parseFloat(transferAmount));
      setSuccessMessage("Transfert effectué avec succès !");
      setTransferFrom("");
      setTransferTo("");
      setTransferAmount("");
      setTimeout(() => setSuccessMessage(""), 3000);
    } catch (err) {
      alert("Erreur lors du transfert: " + (err as Error).message);
    } finally {
      setIsLoading(false);
    }
  };

  if (loading && transactions.length === 0) return <p className="text-center text-white">Chargement...</p>;
  if (error && transactions.length === 0) return <p className="text-red-500 text-center">Erreur : {error}</p>;

  return (
    <div className="bg-[#191E2D] rounded-xl p-6 min-h-screen overflow-y-auto text-white">
      <div className="flex items-center justify-between mb-6">
        <span className="text-[#14CB84] font-bold text-2xl">Transaction History</span>
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
      </div>

      {successMessage && (
        <div className="bg-green-500 text-white p-4 rounded-lg mb-6">
          {successMessage}
        </div>
      )}

      <input
        type="search"
        placeholder="Search by ID, From, or To…"
        className="w-full rounded border border-[#2a3352] bg-[#101828] px-4 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#14CB84] mb-6"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />

      <TransactionTable transactions={filtered} />

      {/* Formulaires Mint & Transfer */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mt-8">
        <div className="bg-[#232A3B] p-6 rounded-xl">
          <h3 className="text-[#14CB84] font-bold mb-4 text-lg">Mint Tokens</h3>
          <input
            placeholder="To (account)"
            className="w-full mb-3 px-4 py-2 bg-[#1A2235] rounded border border-[#2a3352] text-white"
            value={mintTo}
            onChange={(e) => setMintTo(e.target.value)}
          />
          <input
            placeholder="Amount"
            type="number"
            className="w-full mb-4 px-4 py-2 bg-[#1A2235] rounded border border-[#2a3352] text-white"
            value={mintAmount}
            onChange={(e) => setMintAmount(e.target.value)}
          />
          <button
            onClick={handleMint}
            disabled={isLoading}
            className="w-full bg-[#14CB84] px-6 py-2 rounded hover:bg-[#10ab6e] disabled:opacity-50 transition font-semibold"
          >
            {isLoading ? "En cours..." : "Mint"}
          </button>
        </div>

        <div className="bg-[#232A3B] p-6 rounded-xl">
          <h3 className="text-[#14CB84] font-bold mb-4 text-lg">Transfer Tokens</h3>
          <input
            placeholder="From"
            className="w-full mb-3 px-4 py-2 bg-[#1A2235] rounded border border-[#2a3352] text-white"
            value={transferFrom}
            onChange={(e) => setTransferFrom(e.target.value)}
          />
          <input
            placeholder="To"
            className="w-full mb-3 px-4 py-2 bg-[#1A2235] rounded border border-[#2a3352] text-white"
            value={transferTo}
            onChange={(e) => setTransferTo(e.target.value)}
          />
          <input
            placeholder="Amount"
            type="number"
            className="w-full mb-4 px-4 py-2 bg-[#1A2235] rounded border border-[#2a3352] text-white"
            value={transferAmount}
            onChange={(e) => setTransferAmount(e.target.value)}
          />
          <button
            onClick={handleTransfer}
            disabled={isLoading}
            className="w-full bg-[#14CB84] px-6 py-2 rounded hover:bg-[#10ab6e] disabled:opacity-50 transition font-semibold"
          >
            {isLoading ? "En cours..." : "Transfer"}
          </button>
        </div>
      </div>
    </div>
  );
}