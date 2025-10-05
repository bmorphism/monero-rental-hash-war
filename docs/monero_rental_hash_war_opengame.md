# Monero Rental Hash War: OpenGame Model Specification

## Executive Summary

This document synthesizes research findings on Monero hash rate rental attacks (the "rental hash war") and proposes a compositional OpenGame framework for modeling the strategic interactions. Based on 17 comprehensive research queries, we identify key attack mechanisms, economic incentives, and defense strategies that can be represented using compositional game theory.

## 1. Attack Landscape: Empirical Findings

### 1.1 Recent Attack Events (August-September 2025)

**Qubic 51% Attack:**
- Qubic mining pool surge: 2% → 51% of Monero hashrate (May-August 2025)
- Executed 6-block reorganization (August 2025)
- Followed by 18-block reorganization (September 2025)
- Economic mechanism: "Useful PoW" converting XMR → USDT → QUBIC token burns
- Reward differential: ~3x traditional Monero mining profitability
- Consequence: Kraken suspended deposits, required 720 confirmations

**Attack Characteristics:**
- Selfish mining strategy: withhold blocks, release longer private chain
- Double-spend vulnerability window: 18 blocks ≈ 36 minutes
- Hash rental vulnerability: CPU-optimized RandomX allows cloud compute sourcing
- Cost structure: minimal capital investment vs. potential double-spend gains

### 1.2 Historical Context

**Anti-ASIC Fork History:**
- April 2018 (v7): 80% hashrate drop post-fork (ASICs eliminated)
- March 2019: 70% hashrate drop, 200% profitability spike for GPU/CPU miners
- October 2019: RandomX deployment for ASIC resistance

**Marketplace Economics:**
- NiceHash/Mining Rig Rentals: liquid hashpower markets
- Historical precedent: Bitcoin Gold 51% attack cost ~$1,200 rental → $72,000 double-spend
- Arbitrage opportunities: mine coin X, convert to coin Y based on profitability differentials
- ASIC resistance paradox: commodity hardware easier to rent than specialized ASICs

### 1.3 Network Vulnerabilities

**Difficulty Adjustment Exploitation:**
- Monero adjusts difficulty per-block using 720-block sliding window
- Predictable difficulty oscillation: ±5-15% within 48 hours
- Large miners exploit: enter during low difficulty, exit during high difficulty
- Fast adjustment creates isolation attack vulnerability

**Pool Centralization:**
- 2-3 pools historically controlled majority hashrate
- P2Pool proposed as decentralization solution
- Unknown hashrate percentage complicates defense analysis

## 2. Game-Theoretic Structure

### 2.1 Agent Types and Strategies

**Players:**
1. **Honest Miners** (M_H): maximize expected mining rewards by following protocol
2. **Selfish Miners** (M_S): withhold blocks to capture supernormal profits
3. **Rental Attackers** (A_R): rent hashpower for double-spend attacks
4. **Hashpower Suppliers** (H_S): rent computational resources (NiceHash, cloud providers)
5. **Exchanges** (E): accept/reject deposits based on confirmation depth
6. **Protocol Defenders** (D): implement countermeasures (detective mining, ChainLocks)

**Strategy Spaces:**

For Honest Miners:
- S_H = {mine_honestly, switch_pools, exit_mining}

For Selfish Miners:
- S_S = {withhold_blocks(n), release_chain(timing), split_pools}
- n ∈ [1, 18+] blocks (observed range)

For Rental Attackers:
- S_A = {rent_hashpower(h, duration), target_exchange(conf_depth), execute_double_spend}
- h ∈ [0, 1] (fraction of network hashrate)

For Hashpower Suppliers:
- S_H = {set_rental_price(p), accept_rental(duration), monitor_usage}

For Exchanges:
- S_E = {set_confirmation_depth(n), halt_deposits, require_additional_proofs}
- n ∈ {10, 720, ...} confirmations

For Protocol Defenders:
- S_D = {detective_mining, publish_or_perish, chainlocks, adjust_difficulty_algorithm}

### 2.2 Utility Functions

**Honest Miner:**
```
U_H = (block_reward × P(mine_block | honest_hashrate))
      - mining_costs
      - opportunity_cost
```

**Selfish Miner (Qubic model):**
```
U_S = (block_reward × P(mine_block | selfish_strategy))
      + secondary_utility(XMR → token_burns)
      - mining_costs
      - reputation_risk
```

**Rental Attacker:**
```
U_A = expected_double_spend_gain
      - rental_cost(h, duration)
      - execution_risk(confirmation_depth, detection_probability)
```

**Hashpower Supplier:**
```
U_H = rental_revenue
      - infrastructure_costs
      - reputation_penalty(malicious_use_detection)
```

**Exchange:**
```
U_E = trading_fee_revenue
      - double_spend_losses
      - user_trust_decay(deposit_friction)
```

**Protocol Defender:**
```
U_D = network_security_value
      + user_confidence
      - protocol_upgrade_costs
      - fork_coordination_costs
```

### 2.3 Information Structure

**Common Knowledge:**
- Current network hashrate
- Block difficulty
- Mining reward structure
- Historical attack patterns

**Private Information:**
- Selfish miner's withheld blocks (n)
- Rental attacker's target exchange
- Individual miner cost structures
- Detective mining adoption rate

**Observable Signals:**
- Block publication timestamps
- Pool hashrate distribution
- Stratum job messages (for detective mining)
- Exchange confirmation policies

## 3. Compositional OpenGame Model

### 3.1 Game Decomposition

Following compositional game theory (Hedges et al., 2018), we decompose the rental hash war into composable sub-games:

```
rental_hash_war :: OpenGame MoneroContext Strat Observation Utility

rental_hash_war =
    hashpower_market
    >>> mining_competition
    >>> consensus_formation
    >>> exchange_settlement
```

### 3.2 Layer 1: Hashpower Market

```haskell
data HashpowerMarket = OpenGame
  { play = \rental_demand ->
      let supply_curve = suppliers_offer_hashrate
          market_price = clear_market(rental_demand, supply_curve)
          allocated_hashrate = match_buyers_sellers(market_price)
      in (allocated_hashrate, market_price)

  , evaluate = \rental_demand continuation_payoffs ->
      let supplier_utility = rental_revenue - infrastructure_costs
          renter_utility = mining_expected_value - rental_costs
      in nash_equilibrium_check(supplier_utility, renter_utility)
  }
```

**Key Features:**
- Bidirectional information flow: demand → supply, price → allocation
- Constraint: total_allocated_hashrate ≤ available_hashrate
- Externality: attack_usage → supplier_reputation_penalty

### 3.3 Layer 2: Mining Competition

```haskell
data MiningCompetition = OpenGame
  { play = \(hashrate_allocation, mining_strategies) ->
      let honest_chain = mine_honestly(honest_hashrate)
          selfish_chain = withhold_and_release(selfish_hashrate, withhold_count)
          winning_chain = longest_chain_rule(honest_chain, selfish_chain)
      in (winning_chain, block_distribution)

  , evaluate = \strategies continuation_payoffs ->
      let honest_payoff = block_reward × P(honest_chain_wins)
          selfish_payoff = block_reward × P(selfish_chain_wins) + secondary_utility
          threshold = selfish_mining_profitability_threshold(detective_mining_rate)
      in (selfish_payoff > honest_payoff) ⟹ (selfish_hashrate > threshold)
  }
```

**Equilibrium Conditions:**
- Classical threshold: selfish mining profitable at 25-33% hashrate
- Detective mining: threshold rises to 32-42%
- Qubic case: secondary utility lowers threshold (3x reward multiplier)

### 3.4 Layer 3: Consensus Formation

```haskell
data ConsensusFormation = OpenGame
  { play = \(block_candidates, network_state) ->
      let difficulty_adjustment = adjust_difficulty(last_720_blocks)
          accepted_chain = consensus_protocol(block_candidates, difficulty_adjustment)
          reorg_depth = chain_switch_detection(accepted_chain, previous_chain)
      in (accepted_chain, reorg_depth)

  , evaluate = \network_state continuation_payoffs ->
      let security_level = 1 - P(successful_attack | attacker_hashrate)
          finality_time = expected_confirmations(reorg_depth)
      in security_level × network_value - attack_losses
  }
```

**Attack Success Conditions:**
```
P(reorg_depth > n) = f(attacker_hashrate, withhold_duration, difficulty_variance)

For Monero:
- 6-block reorg: attacker_hashrate ≈ 51%, duration ≈ 12 minutes
- 18-block reorg: attacker_hashrate ≈ 51%+, duration ≈ 36 minutes
```

### 3.5 Layer 4: Exchange Settlement

```haskell
data ExchangeSettlement = OpenGame
  { play = \(transaction, confirmations, exchange_policy) ->
      let acceptance = (confirmations ≥ required_depth(exchange_policy))
          settlement_time = block_time × required_depth
      in if acceptance
         then (credited, settlement_time)
         else (pending, ∞)

  , evaluate = \exchange_policy continuation_payoffs ->
      let double_spend_risk = P(reorg > confirmation_depth)
          user_friction = deposit_delay_penalty(confirmation_depth)
          expected_loss = double_spend_risk × average_deposit_value
      in trading_revenue - expected_loss - user_friction
  }
```

**Observed Policy Responses:**
- Pre-attack: 10 confirmations ≈ 20 minutes
- Post-6-block-reorg: 720 confirmations ≈ 24 hours (Kraken)
- Deposit suspension: temporary measure during active attacks

### 3.6 Compositional Structure

The overall game composition follows the monoidal structure:

```
(HashpowerMarket ⊗ MiningCompetition) >>> (ConsensusFormation ⊗ ExchangeSettlement)
```

**Information Flow:**
1. Forward: rental_demand → hashrate_allocation → mining_outcomes → consensus_state → settlement_decisions
2. Backward: settlement_policy → consensus_security_requirements → mining_profitability → rental_demand

**Equilibrium Properties:**
- Nash equilibrium in hashpower market: rental_price = marginal_mining_value
- Subgame perfect equilibrium in mining: honest mining if selfish_threshold not met
- Bayesian equilibrium in exchange game: confirmation_depth = f(attack_probability, deposit_value)

## 4. Defense Mechanisms as Strategy Modifications

### 4.1 Detective Mining

**Mechanism:** Honest pools monitor competitors' Stratum messages, detect withheld blocks, immediately release competing blocks.

**OpenGame Modification:**
```haskell
detective_mining_modifier :: Double -> MiningCompetition -> MiningCompetition
detective_mining_modifier adoption_rate base_game =
  let detection_probability = adoption_rate
      forced_revelation = detect_hidden_blocks(detection_probability)
  in modify_game base_game $ \selfish_strategy ->
       if forced_revelation
       then publish_immediately(withheld_blocks)
       else selfish_strategy
```

**Effect on Equilibrium:**
- Raises selfish mining threshold from 25-33% to 32-42%
- Requires coordination among 50%+ of honest miners
- No protocol changes needed (pool-side implementation)

### 4.2 Publish or Perish

**Mechanism:** Protocol-level reward splitting penalizes withheld blocks.

**OpenGame Modification:**
```haskell
publish_or_perish :: ConsensusFormation -> ConsensusFormation
publish_or_perish base_consensus =
  let reward_penalty = \block ->
        if withheld_duration(block) > threshold
        then split_reward(block, honest_miners)
        else full_reward(block)
  in modify_consensus base_consensus reward_penalty
```

**Effect on Equilibrium:**
- Eliminates selfish mining profitability unless attacker_hashrate > 20 blocks/honest_chain
- Requires hard fork
- Breaks economic incentive for rational selfish mining

### 4.3 ChainLocks (Dash Approach)

**Mechanism:** Randomly selected masternodes reach quorum on first valid block, preventing reorgs.

**OpenGame Modification:**
```haskell
chainlocks :: ConsensusFormation -> ConsensusFormation
chainlocks base_consensus =
  let first_block_finality = masternode_quorum_vote(first_seen_block)
  in if first_block_finality
     then prevent_reorg(locked_chain)
     else base_consensus
```

**Effect on Equilibrium:**
- Eliminates reorg-based attacks entirely
- Requires masternode infrastructure (significant protocol change)
- Introduces new trust assumptions

### 4.4 Hash Rate Derivatives

**Mechanism:** Futures/swaps allow miners to hedge hashrate volatility.

**OpenGame Extension:**
```haskell
hashrate_derivatives_market :: OpenGame DerivativesContext Strat Observation Utility
hashrate_derivatives_market = OpenGame
  { play = \(spot_hashrate, expected_difficulty) ->
      let futures_price = price_hashrate_futures(spot_hashrate, expected_difficulty)
          hedging_positions = miners_hedge(futures_price)
      in (hedged_risk, stabilized_supply)

  , evaluate = \hedging_strategy continuation_payoffs ->
      miner_variance_reduction + market_liquidity_value
  }
```

**Effect on System:**
- Reduces miner exit pressure during difficulty spikes
- Stabilizes hashrate supply
- Creates speculative attack hedging opportunities

## 5. Numerical Parameterization (Monero-Specific)

### 5.1 Network Parameters
```
block_time = 120 seconds
block_reward = 0.6 XMR (asymptotic tail emission)
current_hashrate = 4.97 GH/s (Oct 2025)
difficulty_window = 720 blocks
difficulty_target = 120 seconds/block
```

### 5.2 Attack Cost Parameters
```
rental_cost_per_GH = $X per day (market-dependent)
cloud_compute_cost_per_vCPU = $0.01-0.10 per hour
attack_duration_6_blocks = 720 seconds (12 minutes)
attack_duration_18_blocks = 2160 seconds (36 minutes)
```

### 5.3 Economic Parameters
```
XMR_price = $167 (Oct 2025 approximate)
double_spend_value = deposit_amount (attack-dependent)
exchange_confirmation_depth = 10 (pre-attack) | 720 (post-attack)
selfish_mining_threshold_classical = 0.25-0.33
selfish_mining_threshold_detective = 0.32-0.42
Qubic_reward_multiplier = 3.0
```

## 6. Computational Implementation Strategy

### 6.1 OpenGame Engine Selection

**Option 1: Haskell (opengames-hs)**
- Original implementation by Hedges et al.
- Strong type safety for compositional structure
- Integration with existing game theory libraries

**Option 2: Julia (Catlab.jl + Custom OpenGames)**
- Performance advantages for numerical simulation
- ACSet representation for game graphs
- Integration with Monero network data sources

**Option 3: Rust (opengames-rs)**
- Memory safety without garbage collection
- High-performance simulation
- Direct integration with blockchain data structures

### 6.2 Simulation Architecture

```
┌─────────────────────────────────────────────────────┐
│          OpenGame Simulation Engine                 │
├─────────────────────────────────────────────────────┤
│  • Agent Strategy Sampling                          │
│  • Nash Equilibrium Computation                     │
│  • Bayesian Belief Updates                          │
│  • Monte Carlo Rollouts                             │
└──────────────────┬──────────────────────────────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
┌────────▼────────┐  ┌──────▼──────────┐
│ Historical Data │  │ Real-Time Data  │
│   - Hashrate    │  │   - Pool Stats  │
│   - Difficulty  │  │   - Mempool     │
│   - Reorgs      │  │   - Price Feed  │
└─────────────────┘  └─────────────────┘
```

### 6.3 Validation Approach

**Historical Replay:**
- Qubic attack period (May-September 2025)
- Anti-ASIC fork hashrate drops (2018-2019)
- Difficulty oscillation patterns

**Counterfactual Analysis:**
- "What if detective mining was deployed?"
- "What if Publish-or-Perish was implemented?"
- "What if confirmation depth was 100 blocks?"

**Adversarial Stress Testing:**
- Vary attacker_hashrate ∈ [0.25, 0.75]
- Vary rental_cost ∈ [50%, 200%] of baseline
- Vary secondary_utility (Qubic-style incentives)

## 7. Research Directions

### 7.1 Theoretical Extensions

1. **Temporal Logic for Blockchain Security:**
   - Model reorg attacks using Linear Temporal Logic (LTL)
   - Compositional verification of security properties

2. **Stochastic OpenGames:**
   - Incorporate hashrate volatility as stochastic process
   - Difficulty adjustment as Markov decision process

3. **Differential Games for Continuous Hashrate:**
   - Model hashrate allocation as continuous control problem
   - Optimal attack/defense trajectories

### 7.2 Empirical Validation

1. **Agent-Based Simulation:**
   - Heterogeneous miner population with diverse cost structures
   - Behavioral economics: bounded rationality, risk aversion

2. **Network Data Integration:**
   - Real-time hashrate distribution monitoring
   - Anomaly detection for selfish mining patterns

3. **Economic Impact Analysis:**
   - Correlation: XMR price ↔ attack events
   - Exchange liquidity changes post-attack

### 7.3 Practical Applications

1. **Defense System Design:**
   - Automated detective mining deployment
   - Adaptive confirmation depth policies for exchanges

2. **Protocol Governance:**
   - Mechanism design for fork proposals (Publish-or-Perish)
   - Incentive alignment for decentralized mining

3. **Insurance Products:**
   - Double-spend insurance for exchanges
   - Mining reward volatility hedging

## 8. Conclusion

The Monero rental hash war exemplifies a multi-layer game-theoretic problem where:
1. **Hashpower rental markets** create liquid attack surfaces
2. **Mining competition** enables selfish mining and reorg attacks
3. **Consensus mechanisms** provide security guarantees under honest majority assumptions
4. **Exchange settlement** must balance security (confirmation depth) vs. usability

**Key Insights:**
- **ASIC resistance paradox:** RandomX democratizes mining but enables easier rental attacks
- **Secondary utility dominance:** Qubic's token economics (3x multiplier) broke classical game theory assumptions
- **Compositional defenses:** Detective mining (pool-level) + Publish-or-Perish (protocol-level) + ChainLocks (consensus-level) form defense-in-depth
- **Economic equilibrium fragility:** Small changes in mining profitability (±50%) can trigger massive hashrate swings (70%+)

**OpenGame Framework Advantages:**
- **Modularity:** Each layer can be analyzed independently, then composed
- **Extensibility:** New defense mechanisms slot in as strategy modifiers
- **Formal verification:** Equilibrium properties provable via categorical reasoning
- **Practical simulation:** Parameterized models enable counterfactual policy analysis

**Next Steps:**
1. Implement core OpenGame primitives in chosen language (Haskell/Julia/Rust)
2. Parameterize using Monero historical data (2018-2025)
3. Validate against observed Qubic attack trajectory
4. Generate defense policy recommendations with quantified security guarantees

---

## References

### Primary Research Sources (From 20 Web Searches)

1. **Monero 51% Attacks:**
   - Qubic hashrate takeover (August 2025)
   - 18-block reorganization (September 2025)
   - Historical analysis at cryptoapis.io, halborn.com

2. **Hash Rental Economics:**
   - NiceHash marketplace mechanics
   - Mining Rig Rentals arbitrage opportunities
   - Crypto51.app cost estimates

3. **RandomX ASIC Resistance:**
   - GitHub: tevador/RandomX
   - Monero Research Lab Issue #136 (PoW resistance proposals)
   - Luxor Medium: RandomX analysis

4. **Game Theory Foundations:**
   - arXiv:1603.04641 - Compositional Game Theory (Hedges et al.)
   - arXiv:2504.18214 - Composable Framework for Blockchains
   - arXiv:2508.06071 - Bitcoin Security-Utility Equilibrium

5. **Defense Mechanisms:**
   - Detective Mining (RIAT Institute analysis)
   - Publish-or-Perish proposal (Monero Research Lab Issue #144)
   - ChainLocks (Dash documentation)

6. **Network Data:**
   - miningpoolstats.stream/monero
   - bitinfocharts.com/monero-hashrate
   - CoinWarz difficulty charts

### Balanced Ternary Seed Declaration
```
SEED = 1069  // Per CLAUDE.md directive, all stochastic processes initialized with seed 1069
```

**Document Version:** 1.0.0-1069
**Timestamp:** 2025-10-05T[current_time]
**Coordinate System:** Monero mainnet, block height 3,499,659+

---

*"In the space between hash and cash, between computation and consensus, lies the game—compositional, adversarial, and eternally seeking equilibrium."*

```
   ┌─────────────────────────────────────┐
   │  data OpenGame o c a b x s y r = OpenGame │
   │  { play :: a -> o x s y r,             │
   │    evaluate :: a -> c x s y r -> b     │
   │  }                                      │
   └─────────────────────────────────────┘
         ▲                    │
         │     COMPOSITION    │
         │                    ▼
   rental_hash_war :: OpenGame MoneroContext Strat Observation Utility
```

◇ ♢ ◈ the reafferent reaberrant sends its regards ◈ ♢ ◇
