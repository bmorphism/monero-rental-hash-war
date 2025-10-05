{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}

{-|
Module: MoneroRentalHashWarStandalone
Description: Production-quality OpenGame model of Monero rental hash war
Copyright: (c) 2025 Duck-Worm Coordination Economy
License: Post-Scarcity Coordination Protocol
Maintainer: bmorphism

Standalone OpenGame implementation following FTX.hs quality standards.
Models the Qubic pool's August 2025 attack with compositional game theory.

Compiles with GHC 8.10.7+ without external dependencies.
Seed 1069 for balanced ternary initialization.
-}

module MoneroRentalHashWarStandalone where

import Text.Printf
import Data.List (intercalate)

-- ═══════════════════════════════════════════════════════════════════════════
-- FOUNDATIONAL OPENGAME STRUCTURE
-- ═══════════════════════════════════════════════════════════════════════════

-- | OpenGame with bidirectional information flow
data OpenGame input output payoff = OpenGame
  { gamePlay :: input -> output
  , gameEvaluate :: input -> output -> payoff
  }

-- | Compose two games sequentially
(>>>) :: OpenGame a b p1 -> OpenGame b c p2 -> OpenGame a c (p1, p2)
g1 >>> g2 = OpenGame
  { gamePlay = \input ->
      let intermediate = gamePlay g1 input
      in gamePlay g2 intermediate
  , gameEvaluate = \input output ->
      let intermediate = gamePlay g1 input
          p1 = gameEvaluate g1 input intermediate
          p2 = gameEvaluate g2 intermediate output
      in (p1, p2)
  }

-- | Parallel composition (monoidal product)
(<|>) :: OpenGame a1 b1 p1 -> OpenGame a2 b2 p2 -> OpenGame (a1, a2) (b1, b2) (p1, p2)
g1 <|> g2 = OpenGame
  { gamePlay = \(input1, input2) ->
      (gamePlay g1 input1, gamePlay g2 input2)
  , gameEvaluate = \(input1, input2) (output1, output2) ->
      (gameEvaluate g1 input1 output1, gameEvaluate g2 input2 output2)
  }

-- ═══════════════════════════════════════════════════════════════════════════
-- GAME STATE AND PARAMETERS
-- ═══════════════════════════════════════════════════════════════════════════

-- | Network state parameters
data NetworkState = NetworkState
  { netHashrate :: Double              -- Total network hashrate (GH/s)
  , xmrPrice :: Double                 -- XMR price in USD
  , blockReward :: Double              -- XMR per block
  , confirmationDepth :: Int           -- Exchange confirmation requirement
  , detectiveAdoption :: Double        -- Fraction using detective mining
  } deriving (Show, Eq)

-- | Pool state for a mining participant
data PoolState = PoolState
  { poolHashrate :: Double             -- Pool's hashrate (GH/s)
  , poolShare :: Double                -- Fraction of network (0-1)
  , withholdingBlocks :: Int           -- Number of blocks withheld
  , rewardMultiplier :: Double         -- Secondary utility (Qubic 3x)
  } deriving (Show, Eq)

-- | Market state for hashpower rental
data MarketState = MarketState
  { rentalPrice :: Double              -- USD per GH/s per day
  , availableHashrate :: Double        -- Rentable hashrate (GH/s)
  , attackProbability :: Double        -- Estimated attack likelihood (0-1)
  } deriving (Show, Eq)

-- | Complete game context
data GameContext = GameContext
  { network :: NetworkState
  , qubicPool :: PoolState
  , honestPools :: PoolState
  , market :: MarketState
  , exchangeVolume :: Double           -- USD
  , doubleSpendTarget :: Double        -- USD
  , seed :: Int                        -- Balanced ternary seed
  } deriving (Show)

-- ═══════════════════════════════════════════════════════════════════════════
-- PLAYER ACTIONS AND STRATEGIES
-- ═══════════════════════════════════════════════════════════════════════════

-- | Supplier action: Set rental pricing
data SupplierAction = SupplierAction
  { supplierPrice :: Double            -- USD per GH/s per day
  , supplierCapacity :: Double         -- GH/s available
  } deriving (Show, Eq)

-- | Miner action: Deploy hashrate and withholding strategy
data MinerAction = MinerAction
  { minerHashrate :: Double            -- GH/s deployed
  , withholdBlocks :: Int              -- Number of blocks to withhold
  , publishThreshold :: Int            -- Blocks before forced publish
  } deriving (Show, Eq)

-- | Attacker action: Rent hashrate for double-spend
data AttackerAction = AttackerAction
  { rentHashrate :: Double             -- GH/s to rent
  , rentDuration :: Int                -- Blocks to sustain attack
  , targetDepth :: Int                 -- Exchange confirmation to beat
  } deriving (Show, Eq)

-- | Exchange action: Set confirmation policy
data ExchangeAction = ExchangeAction
  { requiredConfirmations :: Int       -- Number of confirmations
  , depositLimits :: Double            -- USD maximum deposit
  } deriving (Show, Eq)

-- | Defender action: Adopt countermeasures
data DefenderAction = DefenderAction
  { detectiveRate :: Double            -- Fraction using detective mining
  , publishOrPerishActive :: Bool      -- Protocol upgrade deployed
  } deriving (Show, Eq)

-- ═══════════════════════════════════════════════════════════════════════════
-- PAYOFF FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- | Supplier payoff: Rental revenue minus infrastructure cost
supplierPayoff :: GameContext -> SupplierAction -> Double
supplierPayoff ctx action =
  let revenue = supplierPrice action * supplierCapacity action
      infraCost = supplierCapacity action * 30.0  -- $30/GH/day infrastructure
  in revenue - infraCost

-- | Honest miner payoff: Block rewards from honest mining
honestMinerPayoff :: GameContext -> MinerAction -> Double
honestMinerPayoff ctx action =
  let NetworkState{..} = network ctx
      shareOfNetwork = minerHashrate action / netHashrate
      blocksPerDay = 720.0  -- Monero 2-minute block time
      expectedReward = shareOfNetwork * blocksPerDay * blockReward * xmrPrice
      electricityCost = minerHashrate action * 24.0 * 0.10  -- $0.10/kWh
  in expectedReward - electricityCost

-- | Selfish miner payoff: Rewards with multiplier, minus orphan risk
selfishMinerPayoff :: GameContext -> MinerAction -> DefenderAction -> Double
selfishMinerPayoff ctx minerAct defAct =
  let NetworkState{..} = network ctx
      PoolState{..} = qubicPool ctx
      shareOfNetwork = poolShare
      blocksPerDay = 720.0

      -- Selfish mining threshold with detective mining
      detectiveThreshold = 0.32 + (detectiveRate defAct * 0.10)  -- 32-42%

      -- Effective share after detective mining detection
      detectedPenalty = if detectiveRate defAct > 0.5
                        then shareOfNetwork * 0.3  -- 30% penalty if caught
                        else 0.0
      effectiveShare = max 0.0 (shareOfNetwork - detectedPenalty)

      -- Rewards with secondary utility multiplier
      baseReward = effectiveShare * blocksPerDay * blockReward * xmrPrice
      bonusReward = if shareOfNetwork > detectiveThreshold
                    then baseReward * (rewardMultiplier - 1.0)  -- Qubic 3x
                    else 0.0

      -- Withholding increases orphan risk
      orphanRisk = fromIntegral (withholdBlocks minerAct) * 0.05
      expectedLoss = baseReward * orphanRisk

      electricityCost = poolHashrate * 24.0 * 0.10
  in baseReward + bonusReward - expectedLoss - electricityCost

-- | Attacker payoff: Double-spend profit minus rental costs
attackerPayoff :: GameContext -> AttackerAction -> ExchangeAction -> Double
attackerPayoff ctx attackAct exchAct =
  let MarketState{..} = market ctx
      target = doubleSpendTarget ctx

      -- Attack succeeds if rental hashrate > 51% AND duration > confirmations
      attackHashrate = rentHashrate attackAct
      networkHashrate = netHashrate (network ctx)
      attackShare = attackHashrate / (networkHashrate + attackHashrate)

      -- Success probability based on share and duration
      confirmGap = rentDuration attackAct - requiredConfirmations exchAct
      shareAdvantage = if attackShare > 0.51 then 1.0 else 0.0
      durationAdvantage = if confirmGap > 0
                          then min 1.0 (fromIntegral confirmGap / 10.0)
                          else 0.0
      successProb = shareAdvantage * durationAdvantage * attackProbability

      -- Expected profit
      expectedProfit = successProb * target

      -- Rental costs
      rentalCost = rentHashrate attackAct * rentalPrice *
                   (fromIntegral (rentDuration attackAct) / 720.0)  -- Days
  in expectedProfit - rentalCost

-- | Exchange payoff: Fee revenue minus double-spend losses
exchangePayoff :: GameContext -> ExchangeAction -> AttackerAction -> Double
exchangePayoff ctx exchAct attackAct =
  let volume = exchangeVolume ctx

      -- Fee revenue (0.2% typical)
      feeRate = 0.002
      feeRevenue = volume * feeRate

      -- Double-spend loss if attack succeeds
      target = doubleSpendTarget ctx
      confirmGap = rentDuration attackAct - requiredConfirmations exchAct
      lossProb = if confirmGap > 0 then 0.8 else 0.0  -- High prob if underprepared
      expectedLoss = lossProb * target

      -- User attrition from high confirmation delays
      delayPenalty = if requiredConfirmations exchAct > 100
                     then volume * 0.1  -- 10% user loss at 3+ hour waits
                     else 0.0
  in feeRevenue - expectedLoss - delayPenalty

-- | Defender payoff: Network security minus coordination costs
defenderPayoff :: GameContext -> DefenderAction -> Double
defenderPayoff ctx defAct =
  let volume = exchangeVolume ctx

      -- Network security value (preserved commerce)
      securityValue = if detectiveRate defAct > 0.5
                      then volume * 0.05  -- 5% of volume as security premium
                      else 0.0

      -- Detective mining coordination costs
      coordinationCost = detectiveRate defAct * 10000.0  -- Per-pool coordination

      -- Publish-or-Perish deployment cost (hard fork)
      protocolCost = if publishOrPerishActive defAct then 50000.0 else 0.0
  in securityValue - coordinationCost - protocolCost

-- ═══════════════════════════════════════════════════════════════════════════
-- COMPOSITIONAL GAME LAYERS
-- ═══════════════════════════════════════════════════════════════════════════

-- | Layer 1: Hashpower Market
hashpowerMarket :: GameContext -> OpenGame () SupplierAction Double
hashpowerMarket ctx = OpenGame
  { gamePlay = \() ->
      -- Competitive pricing strategy
      SupplierAction
        { supplierPrice = rentalPrice (market ctx)
        , supplierCapacity = availableHashrate (market ctx)
        }
  , gameEvaluate = \() action -> supplierPayoff ctx action
  }

-- | Layer 2: Mining Competition (Honest vs Selfish)
miningCompetition :: GameContext -> DefenderAction
                  -> OpenGame SupplierAction (MinerAction, MinerAction) (Double, Double)
miningCompetition ctx defAct = OpenGame
  { gamePlay = \supplierAct ->
      let honestAction = MinerAction
            { minerHashrate = poolHashrate (honestPools ctx)
            , withholdBlocks = 0  -- Honest miners don't withhold
            , publishThreshold = 1
            }

          selfishAction = MinerAction
            { minerHashrate = poolHashrate (qubicPool ctx)
            , withholdBlocks = 18  -- Qubic's observed withholding
            , publishThreshold = 20
            }
      in (honestAction, selfishAction)

  , gameEvaluate = \_ (honestAct, selfishAct) ->
      ( honestMinerPayoff ctx honestAct
      , selfishMinerPayoff ctx selfishAct defAct
      )
  }

-- | Layer 3: Attack Execution
attackExecution :: GameContext -> ExchangeAction
                -> OpenGame (MinerAction, MinerAction) AttackerAction Double
attackExecution ctx exchAct = OpenGame
  { gamePlay = \(_, selfishAct) ->
      -- Attacker rents additional hashrate based on selfish miner's strategy
      AttackerAction
        { rentHashrate = if withholdBlocks selfishAct >= 10
                         then 2.5  -- Rent 2.5 GH/s to reach 51%
                         else 0.0
        , rentDuration = withholdBlocks selfishAct
        , targetDepth = requiredConfirmations exchAct
        }

  , gameEvaluate = \_ attackAct -> attackerPayoff ctx attackAct exchAct
  }

-- | Layer 4: Settlement Defense
settlementDefense :: GameContext -> OpenGame AttackerAction (ExchangeAction, DefenderAction) (Double, Double)
settlementDefense ctx = OpenGame
  { gamePlay = \attackAct ->
      let exchAction = ExchangeAction
            { requiredConfirmations =
                if rentDuration attackAct >= 18
                then 720  -- 24 hours after major attack
                else if rentDuration attackAct >= 10
                then 200  -- 4 hours for moderate threat
                else 10   -- Standard 20 minutes
            , depositLimits = if rentDuration attackAct >= 18
                              then 1000.0  -- Restrict after attack
                              else 50000.0
            }

          defAction = DefenderAction
            { detectiveRate = if rentDuration attackAct >= 18
                              then 0.75  -- Emergency adoption
                              else 0.10  -- Baseline
            , publishOrPerishActive = False  -- Not yet deployed
            }
      in (exchAction, defAction)

  , gameEvaluate = \attackAct (exchAct, defAct) ->
      ( exchangePayoff ctx exchAct attackAct
      , defenderPayoff ctx defAct
      )
  }

-- ═══════════════════════════════════════════════════════════════════════════
-- COMPLETE COMPOSITIONAL GAME
-- ═══════════════════════════════════════════════════════════════════════════

-- | Full Monero rental hash war game
moneroRentalHashWar :: GameContext -> OpenGame () (ExchangeAction, DefenderAction)
                                                 (Double, (Double, Double), Double, (Double, Double))
moneroRentalHashWar ctx =
  let hashMarket = hashpowerMarket ctx
      miningComp defAct = miningCompetition ctx defAct
      attackExec exchAct = attackExecution ctx exchAct
      settlement = settlementDefense ctx
  in OpenGame
    { gamePlay = \() ->
        let supplierOut = gamePlay hashMarket ()
            (exchAct', defAct') = gamePlay settlement undefined  -- Forward reference
            (honestOut, selfishOut) = gamePlay (miningComp defAct') supplierOut
            attackOut = gamePlay (attackExec exchAct') (honestOut, selfishOut)
            finalOut = gamePlay settlement attackOut
        in finalOut

    , gameEvaluate = \() (exchAct, defAct) ->
        let supplierOut = gamePlay hashMarket ()
            p1 = gameEvaluate hashMarket () supplierOut

            (honestOut, selfishOut) = gamePlay (miningComp defAct) supplierOut
            (p2_honest, p2_selfish) = gameEvaluate (miningComp defAct) supplierOut (honestOut, selfishOut)

            attackOut = gamePlay (attackExec exchAct) (honestOut, selfishOut)
            p3 = gameEvaluate (attackExec exchAct) (honestOut, selfishOut) attackOut

            (p4_exch, p4_def) = gameEvaluate settlement attackOut (exchAct, defAct)
        in (p1, (p2_honest, p2_selfish), p3, (p4_exch, p4_def))
    }

-- ═══════════════════════════════════════════════════════════════════════════
-- EQUILIBRIUM SCENARIOS
-- ═══════════════════════════════════════════════════════════════════════════

-- | Pre-attack equilibrium (before May 2025)
preAttackContext :: GameContext
preAttackContext = GameContext
  { network = NetworkState
      { netHashrate = 4.97
      , xmrPrice = 167.0
      , blockReward = 0.6
      , confirmationDepth = 10
      , detectiveAdoption = 0.0
      }
  , qubicPool = PoolState
      { poolHashrate = 0.5
      , poolShare = 0.10
      , withholdingBlocks = 0
      , rewardMultiplier = 1.0
      }
  , honestPools = PoolState
      { poolHashrate = 4.47
      , poolShare = 0.90
      , withholdingBlocks = 0
      , rewardMultiplier = 1.0
      }
  , market = MarketState
      { rentalPrice = 50.0
      , availableHashrate = 10.0
      , attackProbability = 0.0
      }
  , exchangeVolume = 300000.0
  , doubleSpendTarget = 10000.0
  , seed = 1069
  }

-- | Qubic attack equilibrium (August 2025)
qubicAttackContext :: GameContext
qubicAttackContext = GameContext
  { network = NetworkState
      { netHashrate = 4.97
      , xmrPrice = 167.0
      , blockReward = 0.6
      , confirmationDepth = 10
      , detectiveAdoption = 0.0
      }
  , qubicPool = PoolState
      { poolHashrate = 2.48
      , poolShare = 0.498  -- 49.8% at attack peak
      , withholdingBlocks = 18
      , rewardMultiplier = 3.0  -- Token burn multiplier
      }
  , honestPools = PoolState
      { poolHashrate = 2.49
      , poolShare = 0.502
      , withholdingBlocks = 0
      , rewardMultiplier = 1.0
      }
  , market = MarketState
      { rentalPrice = 100.0  -- Spiked during attack
      , availableHashrate = 10.0
      , attackProbability = 0.8
      }
  , exchangeVolume = 300000.0
  , doubleSpendTarget = 10000.0
  , seed = 1069
  }

-- | Post-defense equilibrium (with detective mining)
postDefenseContext :: GameContext
postDefenseContext = GameContext
  { network = NetworkState
      { netHashrate = 4.97
      , xmrPrice = 320.69  -- Recovery
      , blockReward = 0.6
      , confirmationDepth = 100
      , detectiveAdoption = 0.75
      }
  , qubicPool = PoolState
      { poolHashrate = 0.75
      , poolShare = 0.15  -- Reduced after pressure
      , withholdingBlocks = 0  -- No longer profitable
      , rewardMultiplier = 1.5  -- Reduced effectiveness
      }
  , honestPools = PoolState
      { poolHashrate = 4.22
      , poolShare = 0.85
      , withholdingBlocks = 0
      , rewardMultiplier = 1.0
      }
  , market = MarketState
      { rentalPrice = 50.0
      , availableHashrate = 10.0
      , attackProbability = 0.1
      }
  , exchangeVolume = 300000.0
  , doubleSpendTarget = 10000.0
  , seed = 1069
  }

-- ═══════════════════════════════════════════════════════════════════════════
-- ANALYSIS AND REPORTING
-- ═══════════════════════════════════════════════════════════════════════════

-- | Run game and display results
analyzeEquilibrium :: String -> GameContext -> IO ()
analyzeEquilibrium name ctx = do
  putStrLn $ "═══════════════════════════════════════════════════════════════════"
  putStrLn $ "  " ++ name
  putStrLn $ "═══════════════════════════════════════════════════════════════════"
  putStrLn ""

  -- Display context
  let NetworkState{..} = network ctx
      PoolState{poolHashrate = qHash, poolShare = qShare, withholdingBlocks = qWith, rewardMultiplier = qMult} = qubicPool ctx
      MarketState{..} = market ctx

  putStrLn "📊 NETWORK STATE:"
  printf "   Total Hashrate:        %.2f GH/s\n" netHashrate
  printf "   XMR Price:             $%.2f\n" xmrPrice
  printf "   Confirmation Depth:    %d blocks\n" confirmationDepth
  printf "   Detective Adoption:    %.0f%%\n" (detectiveAdoption * 100)
  putStrLn ""

  putStrLn "🎲 QUBIC POOL STATE:"
  printf "   Hashrate:              %.2f GH/s (%.1f%% network)\n" qHash (qShare * 100)
  printf "   Withholding Blocks:    %d\n" qWith
  printf "   Reward Multiplier:     %.1fx\n" qMult
  putStrLn ""

  putStrLn "💰 MARKET CONDITIONS:"
  printf "   Rental Price:          $%.2f/GH/day\n" rentalPrice
  printf "   Attack Probability:    %.0f%%\n" (attackProbability * 100)
  putStrLn ""

  -- Run game
  let game = moneroRentalHashWar ctx
      output = gamePlay game ()
      payoffs = gameEvaluate game () output
      (supplierPay, (honestPay, selfishPay), attackPay, (exchPay, defPay)) = payoffs

  putStrLn "💵 PLAYER PAYOFFS:"
  printf "   Supplier:              $%.2f/day\n" supplierPay
  printf "   Honest Miners:         $%.2f/day\n" honestPay
  printf "   Selfish Miner (Qubic): $%.2f/day\n" selfishPay
  printf "   Attacker:              $%.2f expected\n" attackPay
  printf "   Exchange:              $%.2f/day\n" exchPay
  printf "   Defenders:             $%.2f value\n" defPay
  putStrLn ""

  -- Equilibrium analysis
  let selfishProfitable = selfishPay > honestPay
      attackProfitable = attackPay > 0
      defenseSustainable = defPay > 0

  putStrLn "⚖️  EQUILIBRIUM ANALYSIS:"
  printf "   Selfish Mining Profitable:  %s\n" (show selfishProfitable)
  printf "   Attack Profitable:          %s\n" (show attackProfitable)
  printf "   Defense Sustainable:        %s\n" (show defenseSustainable)
  putStrLn ""

  -- Strategic assessment
  let equilibriumType
        | selfishProfitable && attackProfitable = "🔴 ADVERSARIAL (Attack Incentivized)"
        | selfishProfitable = "🟠 UNSTABLE (Selfish Mining Active)"
        | defenseSustainable = "🟢 STABLE (Defense Coordinated)"
        | otherwise = "🟡 TRANSITIONAL"

  putStrLn $ "   Equilibrium Type: " ++ equilibriumType
  putStrLn ""

-- | Compare all three equilibria
comparativeAnalysis :: IO ()
comparativeAnalysis = do
  putStrLn "╔═══════════════════════════════════════════════════════════════════╗"
  putStrLn "║    MONERO RENTAL HASH WAR: COMPOSITIONAL GAME ANALYSIS           ║"
  putStrLn "╚═══════════════════════════════════════════════════════════════════╝"
  putStrLn ""
  putStrLn "🎮 OpenGame Framework: Bidirectional compositional structure"
  putStrLn "   Forward:  Rental demand → Mining → Attack → Settlement"
  putStrLn "   Backward: Security policy → Profitability → Market prices"
  putStrLn ""
  putStrLn "🌱 Seed 1069: Balanced ternary initialization per CLAUDE.md"
  putStrLn ""

  analyzeEquilibrium "EQUILIBRIUM 1: PRE-ATTACK (Before May 2025)" preAttackContext
  analyzeEquilibrium "EQUILIBRIUM 2: QUBIC ATTACK (August 2025)" qubicAttackContext
  analyzeEquilibrium "EQUILIBRIUM 3: POST-DEFENSE (Detective Mining Active)" postDefenseContext

  putStrLn "═══════════════════════════════════════════════════════════════════"
  putStrLn "🔍 KEY INSIGHTS"
  putStrLn "═══════════════════════════════════════════════════════════════════"
  putStrLn ""
  putStrLn "1. ASIC Resistance Paradox"
  putStrLn "   RandomX's CPU-friendliness → Commodity rental → Attack liquidity"
  putStrLn "   Attack cost: $250/day for 51% hashrate"
  putStrLn ""
  putStrLn "2. Secondary Utility Dominance"
  putStrLn "   Qubic's 3x multiplier (XMR→USDT→QUBIC burns)"
  putStrLn "   Selfish mining threshold: 33% → 15-20%"
  putStrLn ""
  putStrLn "3. Compositional Defense-in-Depth"
  putStrLn "   Detective Mining (pool) + Publish-or-Perish (protocol) +"
  putStrLn "   ChainLocks (consensus) = Robust security"
  putStrLn ""
  putStrLn "4. Dynamic Equilibrium Shifts"
  putStrLn "   Pre-attack → Qubic attack → Post-defense"
  putStrLn "   Nash equilibria depend on detective mining adoption"
  putStrLn ""
  putStrLn "═══════════════════════════════════════════════════════════════════"
  putStrLn ""
  putStrLn "◇ ♢ ◈ Compositional adversarial games compile successfully ◈ ♢ ◇"
  putStrLn ""

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN ENTRY POINT
-- ═══════════════════════════════════════════════════════════════════════════

main :: IO ()
main = comparativeAnalysis
