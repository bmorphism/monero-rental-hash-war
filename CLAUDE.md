# Monero Rental Hash War - Development Guide

## Seed 1069

**CRITICAL**: All stochastic elements MUST use seed **1069** for reproducibility.

```haskell
-- Haskell random initialization
let rng = mkStdGen 1069

-- Seed offset in calculations
seed_offset = (1069 % 100) / 10000.0  -- 0.0069
```

This ensures:
- Identical results across runs with same inputs
- Balanced ternary encoding compatibility
- Reproducible research findings

## Build Commands

```bash
# Run standalone analysis (recommended)
just run

# Fetch live network data
just fetch-live

# Continuous monitoring
just watch

# Run with live data integration
just run-live

# Clean artifacts
just clean
```

## Code Style

### Haskell
- Use explicit type signatures for all top-level functions
- Prefer `where` clauses over `let` expressions
- Document all OpenGame compositions with ASCII diagrams
- Use seed 1069 for all `mkStdGen` calls

### Python
- Black formatting (100 char line length)
- Type hints for all function signatures
- Use `uvx`/`uv` for dependency management
- Seed 1069 for random/numpy initialization

## OpenGame Composition

**Sequential composition** (`>>>`): Output of first game feeds input of second

```haskell
hashpowerMarket >>> miningCompetition
```

**Parallel composition** (`<|>`): Games run simultaneously, outputs combined

```haskell
attackExecution <|> settlementDefense
```

**Bidirectional flow**:
- **Forward (play)**: Actions propagate through game layers
- **Backward (evaluate)**: Payoffs and strategies back-propagate

## Equilibrium Analysis

The system has three distinct equilibria based on `blockWithholdingScore`:

| Score | Equilibrium | Detective Mining | Confirmations |
|-------|-------------|------------------|---------------|
| <0.3 | Pre-attack | 0-10% | 10 |
| 0.6-0.85 | High-threat | 30-50% | 100-200 |
| >0.85 | Active attack | 10-30% | 720 |

## Testing

Verify equilibria with live data:

```bash
# Fetch current network state
just fetch-live

# Analyze expected equilibrium
runghc src/MoneroRentalHashWarStandalone.hs
```

Expected output regions:
- **Stable** (score <0.3): Honest mining dominant, low orphan rate
- **Unstable** (score >0.7): Selfish mining active, high orphan rate

## Performance Notes

**Interpreted mode** (runghc):
- Startup: ~1-2s
- Memory: ~50MB
- Zero disk space (no binary)

**Native compiled** (ghc --make):
- Startup: <0.1s
- Memory: ~30MB
- Binary: ~2MB

For analysis tools, interpreted mode is **recommended** for maximum portability.

## Compilation Issues

**ARM64 Mac + GHC 8.10.7**:
- Requires LLVM backend (no native codegen)
- Compatible with LLVM 9-13 only
- LLVM 20+ has incompatible flags

**Solutions**:
1. Use `runghc` (recommended)
2. Install `llvm@13` via Homebrew
3. Upgrade to GHC 9.12.2+

See [COMPILATION_NOTES.md](docs/COMPILATION_NOTES.md) for details.

## Jetski Pool Integration

Block withholding score formula:

```python
def calculate_withholding_score(orphaned_blocks: int,
                                pool_dist: List[Tuple[str, float]]) -> float:
    # Orphan rate (18 blocks = Qubic attack signature)
    orphan_score = min(orphaned_blocks / 20.0, 1.0)

    # Pool concentration risk (>30% triggers concern)
    max_pool_share = max(share for _, share in pool_dist)
    concentration_score = max(0, (max_pool_share - 0.3) / 0.2)

    # Combined: 70% orphan rate, 30% concentration
    combined = (orphan_score * 0.7 + concentration_score * 0.3)

    # Seed 1069 offset for balanced ternary reproducibility
    seed_offset = (1069 % 100) / 10000.0
    return min(combined + seed_offset, 1.0)
```

## Error Handling

**GHC compilation errors**:
- Check LLVM version: `opt --version`
- Verify GHC version: `ghc --version`
- Use `runghc` as fallback

**Python API errors**:
- Jetski Pool API may be rate-limited
- Use `--interval` ≥60 for continuous monitoring
- Fallback to cached `examples/jetski_live_data.json`

## Research Context

This implementation analyzes the August 2025 Monero rental hash war where:

1. **Qubic pool** achieved 49.8% network share
2. **18-block withholding** attack observed
3. **3x reward multiplier** (XMR→USDT→QUBIC token burns) lowered selfish mining threshold
4. **Community defense coordination** (confirmations + detective mining) restored equilibrium

Key insight: **Compositional defense-in-depth** without protocol hard fork.

---

◇ ♢ ◈ Computational rigor in adversarial game analysis ◈ ♢ ◇
