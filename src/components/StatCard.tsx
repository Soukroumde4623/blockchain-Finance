import React from "react";

type Props = {
  label: string;
  value: number;
  icon: React.ReactNode;
  positive?: boolean;  // Rendre optionnel
  change?: number;     // Rendre optionnel
};

export default function StatCard({ label, value, icon, positive, change }: Props) {
  return (
    <div className="bg-[#191E2D] rounded-2xl p-6 flex flex-col h-48 justify-between shadow-none">
      {/* Icon */}
      <div className="flex items-center mb-4">
        <div className="w-12 h-12 bg-[#232A3B] rounded-xl flex items-center justify-center">
          {icon}
        </div>
      </div>
      <div>
        <div className="text-gray-400 text-base mb-1">{label}</div>
        <div className="flex items-center justify-between">
          <div className="text-white font-extrabold text-4xl">{value.toLocaleString()}</div>
          
          {/* Afficher le changement seulement si change est défini */}
          {change !== undefined && (
            <span
              className={`ml-2 text-sm px-4 py-1 rounded-xl font-semibold flex items-center ${
                positive
                  ? "bg-green-900 text-green-200"
                  : "bg-red-900 text-red-200"
              }`}
            >
              {positive ? (
                <span className="mr-1">&#8593;</span>
              ) : (
                <span className="mr-1">&#8595;</span>
              )}
              {change}%
            </span>
          )}
        </div>
      </div>
    </div>
  );
}