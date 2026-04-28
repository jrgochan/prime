"use client";

import { useState, useEffect, useRef } from "react";

/**
 * Cache for precomputed certificate data.
 * Keyed by experiment name, persists across mode switches.
 */
const dataCache = new Map<string, unknown>();

/**
 * usePrecomputedData — loads and caches JSON certificates from
 * Rust experiments for Tier 2 visualization modes.
 *
 * @param experimentName - Name of the experiment (e.g., "hilbert-spectral")
 *                         Pass undefined/null to skip loading.
 * @returns { data, loading, error }
 */
export function usePrecomputedData(experimentName: string | undefined | null) {
  const [data, setData] = useState<unknown>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    if (!experimentName) {
      setData(null);
      setLoading(false);
      setError(null);
      return;
    }

    // Check cache first
    const cached = dataCache.get(experimentName);
    if (cached) {
      setData(cached);
      setLoading(false);
      setError(null);
      return;
    }

    // Abort any in-flight request
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    setLoading(true);
    setError(null);

    fetch(`/data/certificates/${experimentName}.json`, {
      signal: controller.signal,
    })
      .then((r) => {
        if (!r.ok) throw new Error(`Certificate not found: ${experimentName}`);
        return r.json();
      })
      .then((json) => {
        dataCache.set(experimentName, json);
        setData(json);
        setLoading(false);
      })
      .catch((e) => {
        if (e.name === "AbortError") return;
        setError(e.message);
        setLoading(false);
      });

    return () => controller.abort();
  }, [experimentName]);

  return { data, loading, error };
}

/**
 * Manually prime the cache with data (for testing or SSR).
 */
export function primeCertificateCache(name: string, data: unknown) {
  dataCache.set(name, data);
}
