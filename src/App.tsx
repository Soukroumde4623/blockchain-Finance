import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { SidebarProvider } from './context/SidebarContext';
import { ScrollToTop } from './components/common/ScrollToTop';

// Pages
import Dashboard from './pages/Dashboard';
import Transactions from './pages/Transactions';
import Account from './pages/Account';
import Users from './pages/Users';
import Blank from './pages/Blank';

// Components globaux
import Sidebar from './components/Sidebar';

// Layout principal avec Sidebar
const MainLayout: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="flex min-h-screen bg-gray-900 text-white">
    <Sidebar />
    <div className="flex-1 flex flex-col">
      <main className="flex-1 overflow-auto p-6">{children}</main>
    </div>
  </div>
);

export default function App() {
  return (
    <Router>
      <ScrollToTop />
      <SidebarProvider>
        <Routes>
          {/* Routes alignées avec le Sidebar */}
          <Route path="/" element={<MainLayout><Dashboard /></MainLayout>} />
          <Route path="/dashboard" element={<MainLayout><Dashboard /></MainLayout>} />
          <Route path="/transaction" element={<MainLayout><Transactions /></MainLayout>} />
          <Route path="/transactions" element={<MainLayout><Transactions /></MainLayout>} />
          <Route path="/account" element={<MainLayout><Account /></MainLayout>} />
          <Route path="/accounts" element={<MainLayout><Account /></MainLayout>} />
          <Route path="/user" element={<MainLayout><Users /></MainLayout>} />
          <Route path="/users" element={<MainLayout><Users /></MainLayout>} />
          <Route path="/blank" element={<MainLayout><Blank /></MainLayout>} />
          {/* Redirection par défaut */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </SidebarProvider>
    </Router>
  );
}