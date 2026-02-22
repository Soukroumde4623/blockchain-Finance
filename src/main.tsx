import { StrictMode } from "react";
import React from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import "swiper/swiper-bundle.css";
import "flatpickr/dist/flatpickr.css";
import App from "./App.tsx";
import { AppWrapper } from "./components/common/PageMeta.tsx";
import { ThemeProvider } from "./context/ThemeContext.tsx";
import { BlockchainProvider } from './context/BlockchainContext';

// ErrorBoundary pour capter les crashs silencieux
class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }
  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error("ErrorBoundary caught:", error, info);
  }
  render() {
    if (this.state.hasError) {
      return (
        <div style={{ color: "white", padding: 40, background: "#1a1a2e" }}>
          <h1 style={{ color: "#ff6b6b" }}>Erreur React</h1>
          <pre style={{ whiteSpace: "pre-wrap", color: "#ffd93d" }}>
            {this.state.error?.message}
          </pre>
          <pre style={{ whiteSpace: "pre-wrap", fontSize: 12, color: "#aaa" }}>
            {this.state.error?.stack}
          </pre>
        </div>
      );
    }
    return this.props.children;
  }
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ErrorBoundary>
      <AppWrapper>
        <ThemeProvider>
          <BlockchainProvider>
            <App />
          </BlockchainProvider>
        </ThemeProvider>
      </AppWrapper>
    </ErrorBoundary>
  </StrictMode>,
);
