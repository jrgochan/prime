"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { ReactNode } from "react";

interface NavItem {
  href: string;
  label: string;
  icon: string;
}

const NAV_ITEMS: NavItem[] = [
  { href: "/", label: "Overview", icon: "🏛️" },
  { href: "/axiom-map", label: "Axiom Map", icon: "🗺️" },
  { href: "/term-explorer", label: "Term Explorer", icon: "🔬" },
  { href: "/proof-tree", label: "Proof Tree", icon: "🌳" },
  { href: "/robin-lagarias", label: "Robin–Lagarias", icon: "🏆" },
  { href: "/gram-heatmap", label: "Gram Matrix", icon: "🔥" },
  { href: "/sawtooth", label: "Sawtooth Discovery", icon: "📐" },
  { href: "/offdiag-margin", label: "Off-Diagonal", icon: "📊" },
  { href: "/fractional-waves", label: "Fractional Waves", icon: "🌊" },
  { href: "/hyperplane-trap", label: "Hyperplane Trap", icon: "🕳️" },
  { href: "/cathedral-3d", label: "Cathedral 3D", icon: "⛪" },
];

export default function Shell({ children }: { children: ReactNode }) {
  const pathname = usePathname();

  return (
    <div className="flex h-screen overflow-hidden">
      <nav className="w-64 flex-shrink-0 bg-[#0d0e1a] border-r border-[#1e2148] flex flex-col">
        <div className="p-6 border-b border-[#1e2148]">
          <h1 className="text-xl font-bold bg-gradient-to-r from-amber-400 to-orange-500 bg-clip-text text-transparent">
            Cathedral
          </h1>
          <p className="text-xs text-slate-500 mt-1">Proof Visualizer v2.0</p>
        </div>

        <div className="flex-1 py-4 px-3 space-y-1 overflow-y-auto">
          {NAV_ITEMS.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all duration-200 ${
                  isActive
                    ? "bg-[#1e2148] text-amber-400 shadow-lg shadow-amber-500/5"
                    : "text-slate-400 hover:text-slate-200 hover:bg-[#12142a]"
                }`}
              >
                <span className="text-lg">{item.icon}</span>
                <span className="font-medium">{item.label}</span>
                {isActive && (
                  <motion.div
                    layoutId="activeNav"
                    className="ml-auto w-1.5 h-1.5 rounded-full bg-amber-400"
                  />
                )}
              </Link>
            );
          })}
        </div>

        <div className="p-4 border-t border-[#1e2148] space-y-2">
          <div className="flex items-center gap-2 text-xs text-slate-600">
            <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>7 crown axioms · 0 sorry · 641 theorems</span>
          </div>
          <div className="w-full h-1 bg-[#1e2148] rounded-full overflow-hidden">
            <div
              className="h-full bg-emerald-500/60 rounded-full"
              style={{ width: "98%" }}
            />
          </div>
          <div className="text-[10px] text-slate-600">
            3,507 build jobs · zero errors
          </div>
        </div>
      </nav>

      <main className="flex-1 overflow-auto bg-[#0a0b14]">
        <AnimatePresence mode="wait">
          <motion.div
            key={pathname}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.2 }}
            className="h-full"
          >
            {children}
          </motion.div>
        </AnimatePresence>
      </main>
    </div>
  );
}
