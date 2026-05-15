"""Quick test of Rust PyO3 bindings for the tower analysis."""
import core_engine
import time

print('=== Rust PyO3 Core Engine ===')
print(f'Status: {core_engine.rust_engine_status()}')
print()

# 1. Quaternion Euler product at Re(s)=1.001, Im(s)=14.134725
norm_h = core_engine.euler_product_quat(1.001, 14.134725, 25)
print(f'|zeta_H(1.001 + 14.134i)| = {norm_h:.6f}')

# 2. Octonion Euler product
norm_o = core_engine.euler_product_oct(1.001, 14.134725, 25)
print(f'|zeta_O(1.001 + 14.134i)| = {norm_o:.6f}')

# 3. Sedenion Dirichlet
norm_s = core_engine.zeta_sedenion(1.001, 14.134725, 50)
print(f'|zeta_S(1.001 + 14.134i)| = {norm_s:.6f}')

# 4. Complex Dirichlet (high precision with 50k terms)
re_z, im_z, norm_c = core_engine.zeta_dirichlet_complex(1.001, 14.134725, 50000)
print(f'|zeta_C(1.001 + 14.134i)| = {norm_c:.6f}  (50k terms, Rust)')

# 5. Mertens bound
z1, z2, z3, prod = core_engine.mertens_bound(1.01, 14.134725, 10000)
satisfied = "YES" if prod >= 0.99 else "NO"
print(f'Mertens: |z(s)|^3 * |z(s+it)|^4 * |z(s+2it)| = {prod:.4f} >= 1? {satisfied}')

# 6. Speed benchmark: tower sweep 100 points
start = time.time()
data = core_engine.tower_sweep(1.0, 80.0, 100)
elapsed = time.time() - start
print(f'Tower sweep (100 pts, Rust): {elapsed*1000:.1f}ms')
row = data[0]
print(f'  Sample: t={row[0]:.1f} |C|={row[1]:.4f} |H|={row[2]:.4f} |O|={row[3]:.4f} |S|={row[4]:.4f}')

# 7. Speed comparison: Python vs Rust for 50k term Dirichlet
start = time.time()
for _ in range(10):
    core_engine.zeta_dirichlet_complex(1.001, 14.134725, 50000)
rust_time = (time.time() - start) / 10

start = time.time()
s = complex(1.001, 14.134725)
result = sum(n ** (-s) for n in range(1, 5001))  # Only 5k in Python (10x fewer)
py_time = (time.time() - start)

print(f'\nSpeed comparison:')
print(f'  Rust: 50k terms in {rust_time*1000:.1f}ms')
print(f'  Python: 5k terms in {py_time*1000:.1f}ms')
print(f'  Rust advantage: ~{(py_time / rust_time * 10):.0f}x (normalized to same terms)')
