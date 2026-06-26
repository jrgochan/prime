"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { ReactNode, useState } from "react";

interface NavItem {
  href: string;
  label: string;
  icon: string;
}

interface NavGroup {
  title: string;
  icon: string;
  items: NavItem[];
  defaultOpen?: boolean;
}

const NAV_GROUPS: NavGroup[] = [
  {
    title: "Cathedral",
    icon: "\u{1F3DB}\uFE0F",
    defaultOpen: true,
    items: [
      { href: "/", label: "Overview", icon: "\u{1F3E0}" },
      { href: "/cathedral-3d", label: "Cathedral 3D", icon: "\u26EA" },
      { href: "/axiom-map", label: "Axiom Map", icon: "\uD83D\uDDFA\uFE0F" },
      { href: "/penta-crown", label: "Penta-Crown", icon: "\u{1F451}" },
    ],
  },
  {
    title: "The Proof",
    icon: "\uD83D\uDCDC",
    defaultOpen: true,
    items: [
      { href: "/proof-tree", label: "Proof Tree", icon: "\uD83C\uDF33" },
      { href: "/perron-chain", label: "Perron Chain", icon: "\u26D3\uFE0F" },
      { href: "/graduation-timeline", label: "Graduations", icon: "\uD83C\uDF93" },
      { href: "/rg-flow", label: "RG Flow", icon: "\u{1F300}" },
      { href: "/dedekind-tree", label: "Dedekind Tree", icon: "\u{1F333}" },
    ],
  },
  {
    title: "Explore",
    icon: "\uD83D\uDD2C",
    defaultOpen: false,
    items: [
      { href: "/term-explorer", label: "Term Explorer", icon: "\u2211" },
      { href: "/gram-heatmap", label: "Gram Matrix", icon: "\uD83D\uDD25" },
      { href: "/fractional-waves", label: "Fractional Waves", icon: "\uD83C\uDF0A" },
      { href: "/offdiag-margin", label: "Off-Diagonal", icon: "\uD83D\uDCCA" },
      { href: "/sawtooth", label: "Sawtooth Discovery", icon: "\uD83D\uDCD0" },
    ],
  },
  {
    title: "Deep Dives",
    icon: "\uD83D\uDCA0",
    defaultOpen: false,
    items: [
      { href: "/hyperplane-trap", label: "Hyperplane Trap", icon: "\uD83D\uDD73\uFE0F" },
      { href: "/robin-lagarias", label: "Robin\u2013Lagarias", icon: "\uD83C\uDFC6" },
      { href: "/standard-model", label: "Standard Model", icon: "\u269B\uFE0F" },
    ],
  },
];

function NavGroupComponent({ group }: { group: NavGroup }) {
  const pathname = usePathname();
  const hasActive = group.items.some((item) => item.href === pathname);
  const [isOpen, setIsOpen] = useState(group.defaultOpen || hasActive);

  return (
    <div className="mb-1">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-center gap-2 px-3 py-2 text-[11px] font-semibold uppercase tracking-wider text-slate-500 hover:text-slate-300 transition-colors"
      >
        <span className="text-sm">{group.icon}</span>
        <span className="flex-1 text-left">{group.title}</span>
        <motion.span
          animate={{ rotate: isOpen ? 90 : 0 }}
          transition={{ duration: 0.15 }}
          className="text-[10px] text-slate-600"
        >
          {"\u25B6"}
        </motion.span>
      </button>
      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2, ease: "easeInOut" }}
            className="overflow-hidden"
          >
            <div className="space-y-0.5 pb-2">
              {group.items.map((item) => {
                const isActive = pathname === item.href;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`flex items-center gap-2.5 px-4 pl-7 py-2 rounded-lg text-sm transition-all duration-200 ${
                      isActive
                        ? "bg-gradient-to-r from-amber-500/15 to-transparent text-amber-400 shadow-lg shadow-amber-500/5"
                        : "text-slate-400 hover:text-slate-200 hover:bg-[#12142a]"
                    }`}
                  >
                    <span className="text-base w-5 text-center">{item.icon}</span>
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
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function Shell({ children }: { children: ReactNode }) {
  const pathname = usePathname();

  return (
    <div className="flex h-screen overflow-hidden">
      <nav className="w-64 flex-shrink-0 bg-[#0d0e1a] border-r border-[#1e2148] flex flex-col">
        <div className="p-5 border-b border-[#1e2148]">
          <Link href="/">
            <h1 className="text-xl font-bold bg-gradient-to-r from-amber-400 to-orange-500 bg-clip-text text-transparent">
              The Cathedral
            </h1>
          </Link>
          <div className="flex items-center gap-2 mt-1.5">
            <span className="text-[10px] text-slate-500">Proof Visualizer</span>
            <span className="text-[9px] px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-400 font-mono font-bold border border-amber-500/20">
              v27
            </span>
          </div>
        </div>

        <div className="flex-1 py-3 px-2 space-y-0 overflow-y-auto">
          {NAV_GROUPS.map((group) => (
            <NavGroupComponent key={group.title} group={group} />
          ))}
        </div>

        <div className="p-4 border-t border-[#1e2148] space-y-2">
          <div className="flex items-center gap-2 text-xs text-slate-500">
            <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Penta-Crown &middot; 0 sorry on crown &middot; ~4,009 proved</span>
          </div>
          <div className="w-full h-1 bg-[#1e2148] rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-emerald-500/60 to-amber-500/40 rounded-full"
              style={{ width: "99%" }}
            />
          </div>
          <div className="text-[10px] text-slate-600">
            ~159K lines &middot; 508 files &middot; 174 axioms
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
