import React from "react";
import { Link, useLocation } from "react-router-dom";
import {
  IconDashboard,
  IconUser,
  IconClipboardList,
  IconUsers,
} from "@tabler/icons-react";

const menu = [
  { label: "Dashboard", to: "/", icon: <IconDashboard size={20} />, active: true },
  { label: "Account", to: "/account", icon: <IconUser size={20} /> },
  { label: "Transaction", to: "/transaction", icon: <IconClipboardList size={20} /> },
  { label: "User", to: "/user", icon: <IconUsers size={20} /> },
];

export default function Sidebar() {
  let location = useLocation();

  return (
    <aside className="w-64 bg-[#191E2D] flex flex-col py-8 px-6 min-h-screen">
      <div className="flex items-center space-x-3 mb-8">
      <img src="../../public/soukreum.png" alt="" />
      </div>
      <nav className="space-y-4">
        {menu.map(({ label, to, icon }) => {
          const active = location.pathname === to;
          return (
            <Link
              key={label}
              to={to}
              className={`flex items-center space-x-3 px-2 py-2 rounded hover:bg-[#232A3B] cursor-pointer ${
                active ? "bg-[#232A3B]" : ""
              }`}
            >
              <span className={`text-lg ${active ? "text-[#14CB84]" : "text-gray-400"}`}>
                {icon}
              </span>
              <span className={`font-medium ${active ? "text-[#14CB84]" : ""}`}>{label}</span>
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
