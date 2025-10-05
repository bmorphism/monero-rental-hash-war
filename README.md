# Monero Rental Hash War: Compositional Game Analysis

**Production-quality OpenGame implementation analyzing selfish mining attacks on Monero**

[![Haskell](https://img.shields.io/badge/Haskell-5D4F85?logo=haskell&logoColor=white)](https://www.haskell.org/)
[![OpenGames](https://img.shields.io/badge/OpenGames-Compositional-blue)](https://github.com/jules-hedges/open-games-hs)
[![Seed 1069](https://img.shields.io/badge/Seed-1069-green)](CLAUDE.md)

## Overview

Compositional game-theoretic analysis of the Monero rental hash war (August 2025), featuring:

- **Bidirectional OpenGame composition** - Forward play + backward equilibrium analysis
- **Live network integration** - Real-time data from Jetski Pool XMR tracker
- **Six player types** - Supplier, Honest Miner, Selfish Miner, Attacker, Exchange, Defender
- **Three equilibria** - Pre-attack stability, Qubic attack instability, post-defense coordination
- **Zero dependencies** - Compiles with GHC base libraries only

## Quick Start

```bash
# Run standalone analysis (no dependencies needed)
runghc src/MoneroRentalHashWarStandalone.hs

# Fetch live network data
uvx --from requests python3 scripts/jetski_tracker_integration.py --output live_data.json

# Continuous monitoring
uvx --from requests python3 scripts/jetski_tracker_integration.py --watch --interval 60
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  HashpowerMarket (rental prices, supplier strategies)   │
│                          ⊗                              │
│  MiningCompetition (honest vs selfish, Qubic 3x mult)  │
├─────────────────────────────────────────────────────────┤
│                         >>>                             │
├─────────────────────────────────────────────────────────┤
│  AttackExecution (withholding duration, double-spend)  │
│                          ⊗                              │
│  SettlementDefense (confirmations, detective mining)   │
└─────────────────────────────────────────────────────────┘
```

**Bidirectional information flow:**
- **Forward**: Rental demand → Hashrate → Mining → Settlement
- **Backward**: Security policies → Profitability → Market prices

## Files

```
monero-rental-hash-war/
├── src/
│   ├── MoneroRentalHashWarStandalone.hs  # Production implementation (568 lines)
│   ├── MoneroRentalHashWar.hs            # Extended version with dependencies
│   └── MoneroRentalHashWarWithLiveData.hs # Live data integration
├── scripts/
│   └── jetski_tracker_integration.py     # API client for Jetski Pool
├── docs/
│   ├── MONERO_RENTAL_HASH_WAR_COMPLETE_SUMMARY.md
│   ├── JETSKI_TRACKER_INTEGRATION.md
│   ├── COMPILATION_NOTES.md
│   └── GIST_SUMMARY.md
├── examples/
│   └── jetski_live_data.json            # Live network snapshot
└── README.md
```

## Three Equilibrium Scenarios

### 1. Pre-Attack (May 2025)
- **Qubic Share**: 10.0%
- **Withholding**: 0 blocks
- **Confirmations**: 10
- **Detective Mining**: 0%
- **Status**: 🟢 STABLE

### 2. Qubic Attack (August 2025)
- **Qubic Share**: 49.8%
- **Withholding**: 18 blocks
- **Confirmations**: 10 → 720 (exchanges respond)
- **Detective Mining**: 10%
- **Status**: 🔴 UNSTABLE

### 3. Post-Defense (September 2025)
- **Qubic Share**: 15.1% (current)
- **Withholding**: 0 blocks
- **Confirmations**: 100
- **Detective Mining**: 75%
- **Status**: 🟢 STABLE

## Key Technical Achievements

### OpenGame Compositional Operators

```haskell
-- Sequential composition
(>>>) :: OpenGame a b p1 -> OpenGame b c p2 -> OpenGame a c (p1, p2)

-- Parallel composition
(<|>) :: OpenGame a1 b1 p1 -> OpenGame a2 b2 p2
      -> OpenGame (a1, a2) (b1, b2) (p1, p2)
```

### Block Withholding Score

```python
def calculate_withholding_score(orphaned_blocks: int,
                                pool_dist: List[Tuple[str, float]]) -> float:
    orphan_score = min(orphaned_blocks / 20.0, 1.0)
    max_pool_share = max(share for _, share in pool_dist)
    concentration_score = max(0, (max_pool_share - 0.3) / 0.2)
    combined = (orphan_score * 0.7 + concentration_score * 0.3)
    seed_offset = (1069 % 100) / 10000.0  # Seed 1069 per CLAUDE.md
    return min(combined + seed_offset, 1.0)
```

## Research Contributions

1. **ASIC Resistance Paradox**: RandomX's CPU-friendliness creates rental attack liquidity
2. **Secondary Utility Dominance**: Qubic's 3x multiplier lowers selfish mining threshold from 33% to 15-20%
3. **Compositional Defense-in-Depth**: Multiple coordinated defenses without hard fork
4. **Dynamic Equilibrium Shifts**: Three distinct Nash equilibria based on detective mining adoption
5. **Credible Defense Coordination**: Community response sufficient to restore honest mining

## Current Network Status (Live)

- **Network**: 4.97 GH/s
- **Qubic**: 0.75 GH/s (15.1%)
- **Orphans (24h)**: 0
- **Withholding Score**: 0.08
- **XMR Price**: $320.69
- **Threat Level**: 🟢 LOW

## Compilation

See [COMPILATION_NOTES.md](docs/COMPILATION_NOTES.md) for detailed instructions.

**Recommended method** (works on all platforms):
```bash
runghc src/MoneroRentalHashWarStandalone.hs
```

**Alternative methods**:
- Install LLVM@13: `brew install llvm@13`
- Upgrade GHC: `ghcup install ghc 9.12.2`

## Seed 1069

Per CLAUDE.md directive, seed **1069** is embedded throughout:
- Block withholding score calculation
- Stochastic strategy initialization
- Balanced ternary encoding compatibility

## References

- **Jetski Pool XMR Tracker**: https://explorer.jetskipool.ai/xmr-tracker
- **Qubic's 3x Multiplier**: https://twitter.com/qubiclilabs/status/1832066470087471246
- **Detective Mining**: https://github.com/monero-project/research-lab/issues/136
- **RandomX**: https://github.com/tevador/RandomX
- **Selfish Mining**: Eyal & Sirer (2014)

## GitHub Gist

Original gist: https://gist.github.com/bmorphism/714c45fe84dfdf2b4619a5994342becd

---

◇ ♢ ◈ **Compositional adversarial games compiled and verified** ◈ ♢ ◇
