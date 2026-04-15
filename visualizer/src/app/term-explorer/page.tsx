"use client";

import dynamic from "next/dynamic";

const TermExplorer = dynamic(() => import("./TermExplorer"), {
  ssr: false,
  loading: () => (
    <div className="p-6 max-w-7xl mx-auto">
      <h1 className="text-3xl font-bold mb-2">
        <span className="bg-gradient-to-r from-amber-400 via-orange-400 to-red-400 bg-clip-text text-transparent">
          Term Explorer
        </span>
      </h1>
      <p className="text-slate-400 text-sm max-w-2xl mb-8">
        Loading interactive workspace...
      </p>
      <div className="h-96 flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-amber-500 border-t-transparent rounded-full animate-spin" />
      </div>
    </div>
  ),
});

export default function TermExplorerPage() {
  return <TermExplorer />;
}
