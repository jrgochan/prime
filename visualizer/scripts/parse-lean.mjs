#!/usr/bin/env node
/**
 * Lean Proof Tree Parser — Extracts theorems, axioms, and dependencies from Cathedral .lean files.
 * Usage: node scripts/parse-lean.mjs [path-to-cathedral]
 */
import { readFileSync, readdirSync, writeFileSync, statSync } from 'fs';
import { join, relative } from 'path';

const CATHEDRAL_PATH = process.argv[2] || join('..', 'proofs', 'Cathedral');

function findLeanFiles(dir) {
  const files = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory() && !entry.startsWith('.')) files.push(...findLeanFiles(full));
    else if (entry.endsWith('.lean')) files.push(full);
  }
  return files;
}

function parseLeanFile(filepath) {
  const content = readFileSync(filepath, 'utf-8');
  const relPath = relative(CATHEDRAL_PATH, filepath);
  const lines = content.split('\n');
  const nodes = [];
  const imports = [];

  for (const line of lines) {
    const m = line.match(/^import\s+([\w.]+)/);
    if (m) imports.push(m[1]);
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const axiomMatch = line.match(/^axiom\s+(\w+)/);
    const thmMatch = line.match(/^(theorem|lemma|def)\s+(\w+)/);

    if (axiomMatch || thmMatch) {
      let sig = '';
      for (let j = i; j < Math.min(i + 5, lines.length); j++) sig += lines[j] + '\n';
      
      if (axiomMatch) {
        nodes.push({ name: axiomMatch[1], type: 'axiom', file: relPath, line: i + 1, signature: sig.trim() });
      } else if (thmMatch) {
        nodes.push({ name: thmMatch[2], type: thmMatch[1], file: relPath, line: i + 1, signature: sig.trim() });
      }
    }
  }
  return { file: relPath, imports, nodes };
}

function buildGraph(parsedFiles) {
  const allNodes = [];
  const edges = [];
  const nodeMap = new Map();

  for (const pf of parsedFiles) {
    for (const node of pf.nodes) {
      if (!nodeMap.has(node.name)) {
        nodeMap.set(node.name, node);
        allNodes.push({ id: node.name, type: node.type, file: node.file, line: node.line, signature: node.signature });
      }
    }
  }

  // Build edges: check if node's proof block references other known names
  for (const pf of parsedFiles) {
    const content = readFileSync(join(CATHEDRAL_PATH, pf.file), 'utf-8');
    for (const node of pf.nodes) {
      const nodeIdx = content.indexOf(node.signature.split('\n')[0]);
      if (nodeIdx < 0) continue;
      const block = content.substring(nodeIdx, nodeIdx + 3000);
      
      for (const [targetName] of nodeMap) {
        if (targetName === node.name) continue;
        if (targetName.length < 4) continue; // Skip very short names
        const regex = new RegExp(`\\b${targetName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`);
        if (regex.test(block) && !block.startsWith(`axiom ${targetName}`) && !block.startsWith(`theorem ${targetName}`)) {
          edges.push({ source: targetName, target: node.name });
        }
      }
    }
  }

  const edgeSet = new Set();
  const uniqueEdges = edges.filter(e => {
    const key = `${e.source}->${e.target}`;
    if (edgeSet.has(key)) return false;
    edgeSet.add(key);
    return true;
  });

  const categories = { axiom: 'axiom', theorem: 'proved', lemma: 'proved', def: 'definition' };

  return {
    nodes: allNodes.map(n => ({ ...n, category: categories[n.type] || 'other' })),
    edges: uniqueEdges,
    meta: {
      totalFiles: parsedFiles.length, totalNodes: allNodes.length, totalEdges: uniqueEdges.length,
      axiomCount: allNodes.filter(n => n.type === 'axiom').length,
      theoremCount: allNodes.filter(n => n.type !== 'axiom' && n.type !== 'def').length,
      generatedAt: new Date().toISOString(),
    },
  };
}

console.log(`Parsing: ${CATHEDRAL_PATH}`);
const leanFiles = findLeanFiles(CATHEDRAL_PATH);
console.log(`Found ${leanFiles.length} .lean files`);
const parsed = leanFiles.map(parseLeanFile);
const graph = buildGraph(parsed);
console.log(`Graph: ${graph.meta.totalNodes} nodes, ${graph.meta.totalEdges} edges (${graph.meta.axiomCount} axioms, ${graph.meta.theoremCount} theorems)`);
const outPath = join('public', 'data', 'proof-tree.json');
writeFileSync(outPath, JSON.stringify(graph, null, 2));
console.log(`Written to ${outPath}`);
