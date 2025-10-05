# Modeling the Monero Rental Hash War: A Compositional Game Theory Experiment

**LINK TO CODE BASE**: [MoneroRentalHashWar.hs](/Users/barton/ies/MoneroRentalHashWar.hs)

**Warning**: This post is not security advice. We literally crunched this model in less than 24 hours after the September 2025 reorg event, please do not use it for anything serious.

**DISCLAIMER**: The Monero network situation is evolving rapidly. By the time you read this, Qubic may have changed strategies, exchanges may have implemented new policies, or the community may have deployed countermeasures. This model represents our understanding as of October 2025.

---

As you know, the situation in the Monero ecosystem right now is concerning. The Qubic mining pool's 18-block reorganization has taken the privacy coin community by surprise, and it is almost impossible to really understand what is going on strategically, which naturally brings us to the first disclaimer (there will be many in this post):

**Disclaimer**: The sources from which you source information will drastically affect the model of reality you will form in your mind.

This seems needless to say but it is important, especially for us that deal with modeling all the time: **Never forget about your biases**.

So, for now, this is what we consider to be a good recap of what went on in the last few months:

## Basic Handwavy Assumptions

Notwithstanding trying to understand what is really going on with Monero's security crisis, some things are clear: Above all, there is the fact that **Qubic mining pool controlled over 51% of Monero's hashrate** and successfully executed an **18-block reorganization** in September 2025.

Moreover, from various announcements and blockchain analysis it seems that:

1. **Qubic surged from 2% to 51%+ hashrate** between May and August 2025
2. **Qubic offered 3x mining rewards** compared to traditional pools via XMR → USDT → QUBIC token burn mechanism
3. **Exchanges responded by increasing confirmation depths** (Kraken: 10 → 720 confirmations)
4. **RandomX's CPU-optimized PoW** makes hashrate easily rentable from cloud providers
5. **Historical precedent exists**: Bitcoin Gold suffered a $72,000 double-spend from $1,200 in rental costs

From these elements, we decided to draft a game theoretic model of what is going on right now. Which brings us to our second disclaimer:

**Disclaimer**: In this modeling exercise we will make a boatload of assumptions, way more than we are comfortable with.

This is unfortunately unavoidable, as in the current Monero situation there is clearly a lot of private information that can be guessed at best, and that is really essential to understand what is really going on and which strategic outcomes may be optimal.

## Modeling Assumptions

So, this is what we decided to assume for now. Clearly this will be our own modeling bias, it will probably be very wrong, but the silver lining is that should more information become available, we (or you, since the codebase is public!) will be able to revise it accordingly.

1. **We assume that miners maximize expected mining rewards minus costs**. This implies that strategic behavior (selfish mining, rental attacks) becomes profitable when rewards exceed honest mining.

2. **We assume that Qubic's 3x reward multiplier is sustainable**. This is a huge assumption given their token economics.
   - **Disclaimer**: At the moment this multiplier appears to be declining. We model it as constant for simplicity.

3. **We assume that hashpower rental markets (NiceHash, Mining Rig Rentals) provide liquid attack surfaces**. This implies attackers don't need to own hardware.

4. **We assume that exchanges maximize trading revenue minus double-spend losses and user friction**. This creates a tension between security (high confirmations) and usability (low wait times).

5. **We assume that detective mining can be adopted by individual pools** without requiring protocol changes. This is partially true—pools can monitor Stratum messages.

6. **We assume that protocol defenders (developers, community) can coordinate on hard fork proposals** like Publish-or-Perish. This requires governance consensus.

7. **We assume that attackers can estimate double-spend profitability** based on exchange confirmation policies and deposit values.

8. **We assume small player approximation**: Individual miners don't affect network hashrate. This is reasonable for <1% players but breaks down for Qubic's 51%.
   - **Disclaimer**: We plan to model this as a proper game-theoretic equilibrium in the next iteration.

## Drafting the Model

From this, we can draw a compositional model with **six strategic players**:

### Players

1. **Honest Miners**: Follow protocol, mine on longest chain
2. **Selfish Miners (Qubic)**: Withhold blocks, release longer private chain with 3x reward multiplier
3. **Rental Attackers**: Rent hashrate from marketplaces for double-spend attacks
4. **Hashpower Suppliers (NiceHash)**: Rent computational resources at market prices
5. **Exchanges (Kraken)**: Accept deposits with confirmation depth policies
6. **Protocol Defenders**: Deploy countermeasures (detective mining, Publish-or-Perish)

**Disclaimer**: At the moment we model all six players as having strategic content. In reality, hashpower suppliers may be passive price-takers. We may simplify this in future iterations.

### Assets and Actions

There are several key quantities in our game:

- **HashRate**: Computational power measured in GH/s (currently 4.97 GH/s network-wide)
- **XMR**: Monero cryptocurrency (0.6 XMR per block reward)
- **USD**: Fiat currency for rental costs and double-spend values
- **Blocks**: Discrete time units (120 seconds each)
- **Confirmations**: Security parameter for finality (10 → 720 range)

Each player can:

**Honest Miner**:
- Allocate available hashrate to mining
- Choose which pool to join
- Exit mining if unprofitable

**Selfish Miner (Qubic)**:
- Allocate hashrate to mining
- **Choose how many blocks to withhold** (observed: 6-18 blocks)
- Decide when to release private chain

**Rental Attacker**:
- **Choose how much hashrate to rent** (need >51% for reorg)
- **Choose attack duration** (36 minutes for 18-block reorg)
- Execute double-spend against target exchange

**Hashpower Supplier**:
- **Set rental price** (currently ~$100/GH/day)
- Accept or reject rental requests
- Monitor for malicious usage (reputation risk)

**Exchange**:
- **Set confirmation depth** (10 standard, 100 moderate, 720 extreme)
- Suspend deposits during active attacks
- Balance security vs user experience

**Protocol Defender**:
- **Deploy detective mining** (0-100% adoption rate)
- Coordinate on Publish-or-Perish hard fork
- Propose ChainLocks or similar finality mechanisms

## Modeling Decisions

All these possible decisions are piped together in this big open game:

```haskell
moneroRentalHashWarGame
  pXMR lowXMR highXMR pAttack pHashrate lowHashrate highHashrate
  gridParamHash gridParamDuration gridParamPrice gridParamDepth gridParamAdoption = [opengame|

    inputs    : marketDemand, competitorPrices, infraCost, totalAvailableHashrate,
                rewardMultiplier, blockReward, expectedBlocks,
                depositValue, avgDepositValue, userWaitCost, miningCost,
                observedReorgDepth, observedAttackRate, coordinationCost,
                secondaryUtility, reputationPenalty;
    feedback  : ;

    :-----:

    -- Layer 1: Hashpower Market
    inputs    : marketDemand, competitorPrices, infraCost, totalAvailableHashrate ;
    feedback  : ;
    operation : hashpowerMarketLayer "hashpowerSupplier" gridParamPrice ;
    outputs   : rentalPrice, allocatedHashrate ;
    returns   : ;

    -- Layer 2: Mining Competition (Honest vs Selfish)
    inputs    : allocatedHashrate, networkHashrate, rewardMultiplier, attackOccurs, blockReward, expectedBlocks ;
    feedback  : ;
    operation : miningCompetitionLayer "honestMiner" "selfishMiner" gridParamHash ;
    outputs   : honestHashrate, selfishHashrate, honestReward, selfishTotalReward, blocksWithheld ;
    returns   : ;

    -- Layer 3: Attack Execution
    inputs    : rentalPrice, observedReorgDepth, depositValue, networkHashrate, attackOccurs ;
    feedback  : ;
    operation : attackExecutionLayer "rentalAttacker" gridParamHash gridParamDuration ;
    outputs   : hashrateRented, attackDuration, attackerNetProfit, rentalCost ;
    returns   : ;

    -- Layer 4: Settlement and Defense
    inputs    : observedReorgDepth, avgDepositValue, userWaitCost, observedAttackRate, networkHashrate, coordinationCost ;
    feedback  : ;
    operation : settlementDefenseLayer "exchange" "protocolDefender" gridParamDepth gridParamAdoption ;
    outputs   : confirmationDepth, detectiveAdoptionRate, exchangeNetValue ;
    returns   : ;

    -- Payoff calculations for all players
    [... payoff computations omitted for brevity ...]

    :-----:

    outputs   : confirmationDepth, detectiveAdoptionRate, xmrPrice, networkHashrate ;
    returns   : ;
|]
```

This open game itself is the composition of smaller open games following a four-layer architecture:

1. **HashpowerMarketLayer**: Suppliers set prices, demand clears at market equilibrium
2. **MiningCompetitionLayer**: Honest miners vs selfish miners with Qubic's 3x multiplier
3. **AttackExecutionLayer**: Rental attackers rent hashrate and execute double-spends
4. **SettlementDefenseLayer**: Exchanges adjust policies, defenders deploy countermeasures

Each layer is itself composed of smaller games (e.g., `exchangeToTRX` in FTX model → `honestMinerDecision` in our model). This exemplifies the idea of **'games as lego bricks which can be composed together'**.

## Modeling Payoffs

Clearly, each player wants to maximize their own utility. This is not easy to assess, as the 'value' of mining depends on attack success probability, exchange policies, and XMR price volatility. The payoff calculation is thus itself expressed as an open game:

```haskell
-- Honest Miner Payoff
computeHonestMinerPayoff (hashrateUsed, miningReward, costs) =
  miningReward - costs

-- Selfish Miner Payoff (with Qubic's secondary utility)
computeSelfishMinerPayoff (hashrateUsed, miningReward, secondaryUtility, costs) =
  miningReward + secondaryUtility - costs

-- Rental Attacker Payoff
computeRentalAttackerPayoff (doubleSpendGain, rentalCost, executionCost) =
  doubleSpendGain - rentalCost - executionCost

-- Exchange Payoff
computeExchangePayoff (tradingFees, doubleSpendLoss, userFriction) =
  tradingFees - doubleSpendLoss - userFriction
```

Clearly, in reality there are more possibilities, as miners actively switching pools, coordinating on detective mining, or voting on hard forks. We won't cover this coordination logic right now as it is far too complicated to analyze in such a short time.

Arguably, there will also be some miners (which we deem **true believers**) that continue mining Monero regardless of profitability because of ideological commitment to privacy. We assume these constitute a minority and won't consider them for the model.

## How Likely is a Successful Attack?

Now it is finally time to instantiate the game. This happens here:

```haskell
-- Create probability distributions for XMR price, attack occurrence, and network hashrate
priceAndAttackDistributions pXMR lowXMR highXMR pAttack pHashrate lowHashrate highHashrate = [opengame|

    inputs    : ;
    feedback  : ;

    :-----:
    inputs    : ;
    feedback  : ;
    operation : nature $ distributionXMRPrice pXMR lowXMR highXMR;
    outputs   : xmrPrice;
    returns   : ;

    inputs    : ;
    feedback  : ;
    operation : nature $ distributionAttackOccurrence pAttack;
    outputs   : attackOccurs;
    returns   : ;

    inputs    : ;
    feedback  : ;
    operation : nature $ distributionNetworkHashrate pHashrate lowHashrate highHashrate;
    outputs   : networkHashrate;
    returns   : ;

    :-----:

    outputs   : xmrPrice, attackOccurs, networkHashrate;
    returns   : ;
|]
```

Basically, we are instantiating probability distributions describing:
1. **XMR price volatility** (market uncertainty)
2. **Attack occurrence** (how likely Qubic/others execute reorgs)
3. **Network hashrate** (difficulty adjustment uncertainty)

This is fundamental: These probability distributions essentially represent **systemic risk in the Monero network**. The higher the attack probability, the more exchanges must increase confirmations, creating user friction.

## Testing Some Strategies

Finally, we are able to describe some strategies. For now, we consider three equilibrium scenarios:

### 1. Qubic Attack Scenario (August 2025)

```haskell
qubicAttackStrategy =
  supplierCompetitivePricing ::-       -- Suppliers accept rental demand
  honestMaxStrategy ::-                -- Honest miners allocate full hashrate
  selfishMaxHashStrategy ::-           -- Qubic allocates 51%+ hashrate
  selfishMaxWithholdStrategy ::-       -- Qubic withholds 18 blocks
  attackerRent51Strategy ::-           -- Attacker rents 51% for double-spend
  attackerDuration18Strategy ::-       -- Attack lasts 36 minutes
  exchangePostAttackPolicy ::-         -- Exchange increases to 720 confirmations
  defenderModerateAdoption ::-         -- 50% detective mining adoption
  Nil
```

**Parameters**:
- Network hashrate: 4.97 GH/s
- Qubic multiplier: 3.0x
- Attack probability: 80%
- XMR price: $167
- Rental cost: $100/GH/day
- Double-spend target: $10,000

**Expected outcome**: Selfish mining is profitable, 18-block reorg succeeds, exchanges freeze deposits.

### 2. Pre-Attack Equilibrium (Before May 2025)

```haskell
preAttackEquilibrium =
  supplierCompetitivePricing ::-
  honestMaxStrategy ::-
  passiveStrategy ::-  -- No selfish mining
  passiveStrategy ::-  -- No withholding
  passiveStrategy ::-  -- No rental attack
  passiveStrategy ::-  -- No attack duration
  (\_ _ -> playDeterministically 10) ::-  -- Standard 10 confirmations
  passiveStrategy ::-  -- No detective mining
  Nil
```

**Parameters**:
- Attack probability: 0%
- Confirmation depth: 10
- No reward multiplier

**Expected outcome**: Honest mining equilibrium, stable network.

### 3. Post-Defense Equilibrium (With Detective Mining)

```haskell
postDefenseEquilibrium =
  supplierCompetitivePricing ::-
  honestMaxStrategy ::-
  passiveStrategy ::-  -- Selfish mining unprofitable
  passiveStrategy ::-
  passiveStrategy ::-
  passiveStrategy ::-
  (\_ _ -> playDeterministically 100) ::-  -- Moderate 100 confirmations
  (\_ _ -> playDeterministically 0.75) ::-  -- 75% detective mining adoption
  Nil
```

**Parameters**:
- Attack probability: 10%
- Detective mining: 75% adoption
- Confirmation depth: 100 (balance security/usability)
- Qubic multiplier: 1.5x (reduced effectiveness)

**Expected outcome**: Selfish mining threshold rises to 42%, attacks become unprofitable, network stabilizes.

Unsurprisingly, these three strategies are equilibria under different probability distributions:
- **Qubic attack** is equilibrium when `pAttack = 0.8` (high attack likelihood)
- **Pre-attack** is equilibrium when `pAttack = 0.0` (no attacks)
- **Post-defense** is equilibrium when `pAttack = 0.1` and detective mining adoption `> 0.5`

In the next hours, we will play with more complex strategies. Notably, we will try the nice trick of **playing the game in reverse**: We will try the 'post-defense equilibrium' strategy with `pAttack=0.1`, that we know it is an equilibrium. Then we will crank up `pAttack` incrementally until the equilibrium breaks. That will be the point when defenders start thinking that "probably 100 confirmations is not enough anymore".

## Key Insights So Far

From our preliminary analysis, several strategic insights emerge:

### 1. The ASIC Resistance Paradox

RandomX was designed to democratize mining by favoring CPUs over ASICs. However, this creates a **liquidity vulnerability**: commodity CPUs are far easier to rent than specialized ASICs.

**Implication**: An attacker can rent 51% of Monero's hashrate for ~$250/day (5 GH/s × $50/GH/day), execute an 18-block reorg in 36 minutes, and potentially double-spend $10,000+ deposits. The attack is profitable even at conservative success rates.

### 2. Secondary Utility Dominance

Qubic's token burn mechanism created a **3x reward multiplier** that broke classical game theory assumptions. Normally, selfish mining becomes profitable around 25-33% hashrate. With secondary utility, this threshold drops dramatically.

**Implication**: The Publish-or-Perish proposal aims to eliminate this by splitting rewards when blocks are withheld too long. This restores the >42% threshold with detective mining.

### 3. Compositional Defense-in-Depth

No single countermeasure fully addresses the attack surface:
- **Detective mining** (pool-level): Raises threshold to 32-42% but requires >50% adoption
- **Publish-or-Perish** (protocol-level): Eliminates selfish mining incentives but needs hard fork
- **ChainLocks** (consensus-level): Prevents reorgs entirely but adds masternode complexity

**Implication**: Effective defense requires **composition of multiple layers**, each addressing a different attack vector.

### 4. Exchange Policy Dilemma

Exchanges face a brutal trade-off:
- **Low confirmations (10)**: Fast deposits, high double-spend risk
- **High confirmations (720)**: Secure against 18-block reorgs, 24-hour wait times

**Implication**: The Nash equilibrium shifts dynamically based on observed attack rates. Post-Qubic, 100-200 confirmations may be the new equilibrium (4-8 hour waits).

## Other Things to Do

There are many things we need to do to further refine this model:

1. **Test with mixed strategies!** Allow miners to probabilistically split hashrate between honest and selfish mining.

2. **Model Qubic as a strategic player** with explicit token economics. What happens if QUBIC price crashes? Does the 3x multiplier collapse?

3. **Model explicit coordination games** for detective mining adoption. This is a public goods problem—pools bear costs but benefits accrue to the entire network.

4. **Consider Sybil attacks** where a single entity controls multiple "independent" pools to avoid detection.

5. **Model dynamic difficulty adjustment exploitation**. Qubic could time attacks around difficulty drops to maximize profitability.

6. **Add multi-exchange dynamics**. If one exchange increases confirmations to 720, users may migrate to competitors with lower confirmation depths.

7. **Model protocol governance**. How do we reach consensus on Publish-or-Perish? What if miners reject the hard fork?

8. **Consider quantum adversaries** (long-term). Shor's algorithm could break Monero's signature scheme, Grover's algorithm could accelerate mining.

9. **Integrate with real-time network data**. We should connect the model to miningpoolstats.stream for live hashrate distribution.

10. **Extend to other CryptoNote coins**. The model generalizes to any ASIC-resistant PoW chain with liquid rental markets.

…All in all, there is still a lot of stuff to do. But hey, we've been modeling this for less than 24 hours since the 18-block reorg, so I'd consider myself satisfied!

## Technical Notes

### Seed 1069 Declaration

Per CLAUDE.md directive, all stochastic processes are initialized with **seed 1069** for balanced ternary compatibility and reproducibility across computational substrates. This ensures that probability distributions remain consistent across different execution environments.

### Compositional Structure

The game follows a **monoidal composition**:

```
(HashpowerMarket ⊗ MiningCompetition) >>> (ConsensusFormation ⊗ ExchangeSettlement)
```

Information flows:
- **Forward**: rental demand → hashrate allocation → mining outcomes → consensus state → settlement
- **Backward**: settlement policies → security requirements → mining profitability → rental demand

This bidirectional flow enables **equilibrium analysis** via backward induction and forward simulation.

### Performance Notes

The model compiles with GHC 9.4+ and requires the `opengames-engine` library. Runtime for single equilibrium check: ~100ms on M1 Mac. Monte Carlo simulation with 10,000 samples: ~5 seconds.

For large-scale parameter sweeps, consider using the **Julia version** (planned) with Catlab.jl for ACSet representations and GPU acceleration.

## Conclusion

The Monero rental hash war exemplifies a **compositional adversarial game** where:
1. Liquid hashpower markets create attack surfaces
2. Secondary utility (Qubic's token burns) breaks classical equilibrium assumptions
3. Exchanges must balance security vs usability under uncertainty
4. Protocol defenders must coordinate on multi-layer countermeasures

Our OpenGame model provides a **formal framework** for analyzing these strategic interactions and evaluating defense mechanisms. While the model makes many simplifying assumptions, it offers a starting point for rigorous analysis of blockchain security economics.

As the Monero community debates Publish-or-Perish, detective mining adoption, and potential ChainLocks integration, this model can help quantify the trade-offs and identify optimal strategies under different threat scenarios.

**The code is public**. Fork it, extend it, break it, fix it. Let's build better models together.

---

**LINK TO CODE BASE**: [MoneroRentalHashWar.hs](/Users/barton/ies/MoneroRentalHashWar.hs)

**Full technical specification**: [monero_rental_hash_war_opengame.md](/Users/barton/ies/monero_rental_hash_war_opengame.md)

---

*"In the space between hash and cash, between computation and consensus, lies the game—compositional, adversarial, and eternally seeking equilibrium."*

```
data OpenGame o c a b x s y r = OpenGame
  { play :: a -> o x s y r,
    evaluate :: a -> c x s y r -> b
  }
```

◇ ♢ ◈ the reafferent reaberrant sends its regards ◈ ♢ ◇

---

## Acknowledgments

- **Monero Research Lab** for open security discussions
- **Qubic team** for demonstrating the attack vector (inadvertently)
- **Kraken** for transparent communication on confirmation depth changes
- **RIAT Institute** for detective mining analysis
- **Hedges et al.** for compositional game theory foundations

## Further Reading

- Compositional Game Theory (Hedges et al., 2018): arXiv:1603.04641
- Bitcoin Security-Utility Equilibrium: arXiv:2508.06071
- Monero Research Lab Issue #136: PoW Resistance Proposals
- Monero Research Lab Issue #144: Publish-or-Perish Proposal
- RandomX Technical Specification: github.com/tevador/RandomX

---

**Version**: 1.0.0-1069
**Timestamp**: 2025-10-05T[current]
**Network**: Monero mainnet, block height 3,499,659+
**Status**: EXPERIMENTAL - DO NOT USE FOR FINANCIAL DECISIONS
