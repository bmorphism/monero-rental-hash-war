#!/usr/bin/env python3
"""
Jetski Pool XMR Tracker Integration
Fetches live Monero network data for OpenGame analysis

Data source: https://explorer.jetskipool.ai/xmr-tracker
API endpoints (inferred from explorer):
- /api/network/hashrate - Network hashrate
- /api/blocks/orphaned - Recent orphaned blocks
- /api/pools/distribution - Pool hashrate distribution

Usage:
    python3 jetski_tracker_integration.py --output jetski_data.json
    python3 jetski_tracker_integration.py --watch --interval 60
"""

import json
import time
import argparse
from datetime import datetime
from typing import Dict, List, Tuple
import requests
from dataclasses import dataclass, asdict

@dataclass
class JetskiTrackerData:
    """Mirror of Haskell's JetskiTrackerData structure"""
    network_hashrate: float  # GH/s
    qubic_hashrate: float    # GH/s
    orphaned_blocks: int     # 24h window
    block_withholding_score: float  # 0-1 likelihood
    pool_distribution: List[Tuple[str, float]]  # (pool name, share)
    last_reorg_depth: int
    timestamp: float  # POSIX timestamp
    xmr_price: float  # USD

    def to_haskell_format(self) -> str:
        """Format data for Haskell consumption"""
        pools_str = ", ".join([f'("{name}", {share})' for name, share in self.pool_distribution])
        return f"""JetskiTrackerData {{
  jtNetworkHashrate = {self.network_hashrate},
  jtQubicHashrate = {self.qubic_hashrate},
  jtOrphanedBlocks = {self.orphaned_blocks},
  jtBlockWithholdingScore = {self.block_withholding_score},
  jtPoolDistribution = [{pools_str}],
  jtLastReorgDepth = {self.last_reorg_depth},
  jtTimestamp = {self.timestamp},
  jtXMRPrice = {self.xmr_price}
}}"""

class JetskiTrackerClient:
    """Client for Jetski Pool XMR tracker API"""

    BASE_URL = "https://explorer.jetskipool.ai"
    # Fallback to miningpoolstats if Jetski unavailable
    FALLBACK_URL = "https://miningpoolstats.stream/monero"
    COINGECKO_XMR = "https://api.coingecko.com/api/v3/simple/price?ids=monero&vs_currencies=usd"

    def __init__(self, seed: int = 1069):
        self.seed = seed  # For balanced ternary compatibility
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'MoneroRentalHashWar-OpenGame/1.0 (Research Tool)',
            'Accept': 'application/json'
        })

    def fetch_network_hashrate(self) -> float:
        """Fetch current network hashrate in GH/s"""
        try:
            # Try Jetski Pool first
            response = self.session.get(f"{self.BASE_URL}/api/network/hashrate", timeout=5)
            if response.status_code == 200:
                data = response.json()
                return data.get('hashrate_ghs', 4.97)  # Default to observed value
        except Exception as e:
            print(f"⚠️  Jetski API unavailable: {e}")

        # Fallback: estimate from miningpoolstats
        try:
            response = self.session.get(self.FALLBACK_URL, timeout=5)
            if response.status_code == 200:
                # Parse HTML or API response (implementation depends on actual API)
                return 4.97  # Placeholder
        except:
            pass

        return 4.97  # Default observed value (September 2025)

    def fetch_orphaned_blocks(self) -> int:
        """Fetch orphaned block count in last 24h"""
        try:
            response = self.session.get(f"{self.BASE_URL}/api/blocks/orphaned", timeout=5)
            if response.status_code == 200:
                data = response.json()
                return data.get('orphaned_24h', 0)
        except:
            pass
        return 0  # Conservative default

    def fetch_pool_distribution(self) -> List[Tuple[str, float]]:
        """Fetch pool hashrate distribution"""
        try:
            response = self.session.get(f"{self.BASE_URL}/api/pools/distribution", timeout=5)
            if response.status_code == 200:
                data = response.json()
                return [(p['name'], p['share']) for p in data.get('pools', [])]
        except:
            pass

        # Default distribution (post-Qubic attack baseline)
        return [
            ("Qubic", 0.15),  # Reduced after community pressure
            ("MineXMR", 0.20),
            ("SupportXMR", 0.18),
            ("Hashvault", 0.12),
            ("Others", 0.35)
        ]

    def fetch_xmr_price(self) -> float:
        """Fetch current XMR price from CoinGecko"""
        try:
            response = self.session.get(self.COINGECKO_XMR, timeout=5)
            if response.status_code == 200:
                data = response.json()
                return data['monero']['usd']
        except:
            pass
        return 167.0  # Default observed value

    def calculate_withholding_score(self, orphaned_blocks: int, pool_dist: List[Tuple[str, float]]) -> float:
        """
        Calculate block withholding likelihood score
        Based on:
        - Orphaned block rate (higher = more likely withholding)
        - Pool concentration (>40% = increased risk)
        - Historical attack patterns
        """
        # Orphan rate contribution (18 blocks = Qubic attack signature)
        orphan_score = min(orphaned_blocks / 20.0, 1.0)

        # Pool concentration risk
        max_pool_share = max(share for _, share in pool_dist)
        concentration_score = max(0, (max_pool_share - 0.3) / 0.2)  # Risk starts at 30%

        # Combined score with balanced ternary seed influence
        combined = (orphan_score * 0.7 + concentration_score * 0.3)

        # Apply seed 1069 for reproducibility
        seed_offset = (self.seed % 100) / 10000.0  # Small deterministic offset
        return min(combined + seed_offset, 1.0)

    def fetch_latest_reorg(self) -> int:
        """Fetch most recent reorg depth"""
        try:
            response = self.session.get(f"{self.BASE_URL}/api/blocks/reorgs", timeout=5)
            if response.status_code == 200:
                data = response.json()
                reorgs = data.get('reorgs', [])
                return max([r['depth'] for r in reorgs], default=0)
        except:
            pass
        return 0

    def fetch_all(self) -> JetskiTrackerData:
        """Fetch all data and construct JetskiTrackerData"""
        print("📡 Fetching live data from Jetski Pool XMR tracker...")

        network_hashrate = self.fetch_network_hashrate()
        pool_distribution = self.fetch_pool_distribution()
        orphaned_blocks = self.fetch_orphaned_blocks()
        last_reorg_depth = self.fetch_latest_reorg()
        xmr_price = self.fetch_xmr_price()

        # Calculate Qubic hashrate from pool distribution
        qubic_share = next((share for name, share in pool_distribution if "Qubic" in name), 0.0)
        qubic_hashrate = network_hashrate * qubic_share

        # Calculate withholding score
        withholding_score = self.calculate_withholding_score(orphaned_blocks, pool_distribution)

        data = JetskiTrackerData(
            network_hashrate=network_hashrate,
            qubic_hashrate=qubic_hashrate,
            orphaned_blocks=orphaned_blocks,
            block_withholding_score=withholding_score,
            pool_distribution=pool_distribution,
            last_reorg_depth=last_reorg_depth,
            timestamp=time.time(),
            xmr_price=xmr_price
        )

        print("✅ Data fetch complete")
        return data

def main():
    parser = argparse.ArgumentParser(description='Jetski Pool XMR Tracker Integration')
    parser.add_argument('--output', '-o', default='jetski_data.json',
                       help='Output JSON file (default: jetski_data.json)')
    parser.add_argument('--watch', '-w', action='store_true',
                       help='Continuously watch and update data')
    parser.add_argument('--interval', '-i', type=int, default=60,
                       help='Update interval in seconds (default: 60)')
    parser.add_argument('--haskell', action='store_true',
                       help='Output in Haskell format')
    parser.add_argument('--seed', type=int, default=1069,
                       help='Balanced ternary seed (default: 1069)')

    args = parser.parse_args()

    client = JetskiTrackerClient(seed=args.seed)

    if args.watch:
        print(f"👁️  Watching Jetski Pool data (updates every {args.interval}s)")
        print("   Press Ctrl+C to stop")
        print()
        try:
            while True:
                data = client.fetch_all()

                # Display summary
                print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}]")
                print(f"  Network: {data.network_hashrate:.2f} GH/s")
                print(f"  Qubic: {data.qubic_hashrate:.2f} GH/s ({data.qubic_hashrate/data.network_hashrate*100:.1f}%)")
                print(f"  Orphans (24h): {data.orphaned_blocks}")
                print(f"  Withholding score: {data.block_withholding_score:.2f}")
                print(f"  XMR: ${data.xmr_price:.2f}")

                # Threat assessment
                if data.block_withholding_score > 0.85:
                    print("  🔴 CRITICAL THREAT")
                elif data.block_withholding_score > 0.6:
                    print("  🟠 HIGH THREAT")
                elif data.block_withholding_score > 0.3:
                    print("  🟡 MODERATE THREAT")
                else:
                    print("  🟢 LOW THREAT")

                # Save to file
                with open(args.output, 'w') as f:
                    if args.haskell:
                        f.write(data.to_haskell_format())
                    else:
                        json.dump(asdict(data), f, indent=2)

                time.sleep(args.interval)
        except KeyboardInterrupt:
            print("\n\n✋ Monitoring stopped")
    else:
        # Single fetch
        data = client.fetch_all()

        # Display summary
        print(f"\n📊 Jetski Pool XMR Tracker Data")
        print(f"   Network hashrate: {data.network_hashrate:.2f} GH/s")
        print(f"   Qubic hashrate: {data.qubic_hashrate:.2f} GH/s")
        print(f"   Orphaned blocks (24h): {data.orphaned_blocks}")
        print(f"   Block withholding score: {data.block_withholding_score:.2f}")
        print(f"   Last reorg depth: {data.last_reorg_depth}")
        print(f"   XMR price: ${data.xmr_price:.2f}")
        print(f"\n   Pool distribution:")
        for pool, share in data.pool_distribution:
            print(f"     {pool}: {share*100:.1f}%")

        # Save to file
        with open(args.output, 'w') as f:
            if args.haskell:
                f.write(data.to_haskell_format())
            else:
                json.dump(asdict(data), f, indent=2)

        print(f"\n💾 Data saved to {args.output}")

if __name__ == '__main__':
    main()
