{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RecordWildCards #-}

{-|
Module: MoneroRentalHashWarWithLiveData
Description: Monero rental hash war game with Jetski Pool live data integration
Copyright: (c) 2025 Duck-Worm Coordination Economy
License: Post-Scarcity Coordination Protocol

Enhanced version integrating https://explorer.jetskipool.ai/xmr-tracker for:
- Real-time network hashrate monitoring
- Orphaned block detection (selfish mining evidence)
- Pool distribution dynamics
- Block withholding pattern analysis
-}

module MoneroRentalHashWarWithLiveData where

import Engine.Engine
import Preprocessor.Preprocessor
import Data.Time.Clock.POSIX (POSIXTime, getPOSIXTime)
import Control.Monad (when)
import System.Random (mkStdGen, Random)

-- ========================================================================
-- LIVE DATA INTEGRATION LAYER
-- ========================================================================

-- | Jetski Pool XMR tracker data structure
data JetskiTrackerData = JetskiTrackerData
  { jtNetworkHashrate :: Double        -- Current network hashrate (GH/s)
  , jtQubicHashrate :: Double          -- Qubic pool hashrate
  , jtOrphanedBlocks :: Int            -- Recent orphaned blocks (24h window)
  , jtBlockWithholdingScore :: Double  -- 0-1 score indicating withholding likelihood
  , jtPoolDistribution :: [(String, Double)]  -- Pool name → hashrate share
  , jtLastReorgDepth :: Int            -- Most recent reorg depth
  , jtTimestamp :: POSIXTime           -- Data timestamp
  , jtXMRPrice :: Double               -- Current XMR price from CoinGecko
  } deriving (Show, Eq)

-- | Mock live data fetcher (replace with actual HTTP API call)
fetchJetskiTrackerData :: IO JetskiTrackerData
fetchJetskiTrackerData = do
  currentTime <- getPOSIXTime
  -- In production, this would make HTTP GET to:
  -- https://explorer.jetskipool.ai/api/xmr-tracker
  -- For now, return realistic mock data based on September 2025 observations
  return $ JetskiTrackerData
    { jtNetworkHashrate = 4.97  -- GH/s (post-attack baseline)
    , jtQubicHashrate = 2.48    -- ~50% during peak attack
    , jtOrphanedBlocks = 18     -- Qubic's 18-block reorg
    , jtBlockWithholdingScore = 0.87  -- High probability of withholding
    , jtPoolDistribution =
        [ ("Qubic", 0.498)
        , ("MineXMR", 0.15)
        , ("SupportXMR", 0.12)
        , ("Others", 0.232)
        ]
    , jtLastReorgDepth = 18
    , jtTimestamp = currentTime
    , jtXMRPrice = 167.0  -- USD
    }

-- | Enhanced context with live data integration
data MoneroContextLive = MoneroContextLive
  { networkHashrate :: Double
  , rentalPricePerGH :: Double
  , blockReward :: Double
  , confirmationDepth :: Double
  , qubicMultiplier :: Double
  , detectiveAdoption :: Double
  , exchangeVolume :: Double
  , doubleSpendTarget :: Double
  , infraCostPerGH :: Double
  , competitorPrices :: [Double]
  , marketDemand :: Double
  , totalAvailableHashrate :: Double
  , rewardMultiplier :: Double
  , expectedBlocks :: Double
  , riskTolerance :: Double
  , xmrPrice :: Double
  , pAttack :: Double
  -- NEW: Live data integration
  , jetskiData :: JetskiTrackerData
  , liveDataUpdateInterval :: Int  -- Seconds between updates
  , blockWithholdingThreshold :: Double  -- Trigger defensive response
  } deriving (Show, Eq)

-- | Initialize context with live Jetski data
initialContextMoneroLive :: Double -> Double -> Double -> Double -> Double
                         -> Double -> Double -> Double -> Double
                         -> JetskiTrackerData -> MoneroContextLive
initialContextMoneroLive netHash rental reward depth multiplier
                        detective volume target infra jetski =
  MoneroContextLive
    { networkHashrate = jtNetworkHashrate jetski  -- Use live data!
    , rentalPricePerGH = rental
    , blockReward = reward
    , confirmationDepth = depth
    , qubicMultiplier = multiplier
    , detectiveAdoption = detective
    , exchangeVolume = volume
    , doubleSpendTarget = target
    , infraCostPerGH = infra
    , competitorPrices = [rental * 0.9, rental * 1.1]
    , marketDemand = 1000.0
    , totalAvailableHashrate = jtNetworkHashrate jetski * 2.0
    , rewardMultiplier = multiplier
    , expectedBlocks = jtQubicHashrate jetski / jtNetworkHashrate jetski * 720
    , riskTolerance = 0.5
    , xmrPrice = jtXMRPrice jetski
    , pAttack = if jtBlockWithholdingScore jetski > 0.7 then 0.8 else 0.1
    , jetskiData = jetski
    , liveDataUpdateInterval = 60  -- Update every minute
    , blockWithholdingThreshold = 0.75  -- Alert threshold
    }

-- ========================================================================
-- ENHANCED STRATEGIES WITH LIVE DATA AWARENESS
-- ========================================================================

-- | Selfish mining strategy informed by Jetski orphaned block detection
selfishAdaptiveStrategy :: JetskiTrackerData -> Double
selfishAdaptiveStrategy jetski
  | jtBlockWithholdingScore jetski > 0.8 = 0.9  -- Aggressive withholding
  | jtBlockWithholdingScore jetski > 0.5 = 0.6  -- Moderate withholding
  | otherwise = 0.0  -- Honest mining when detection risk high

-- | Attack duration adjusted by real-time reorg depth monitoring
attackDurationByReorgHistory :: JetskiTrackerData -> Double
attackDurationByReorgHistory jetski
  | jtLastReorgDepth jetski >= 18 = 18.0  -- Replicate successful attack
  | jtLastReorgDepth jetski >= 10 = fromIntegral (jtLastReorgDepth jetski)
  | otherwise = 6.0  -- Conservative 6-block withholding

-- | Exchange response based on observed orphan rate
exchangeConfirmationPolicy :: JetskiTrackerData -> Double
exchangeConfirmationPolicy jetski
  | jtOrphanedBlocks jetski >= 18 = 720.0  -- 24-hour wait after major reorg
  | jtOrphanedBlocks jetski >= 10 = 200.0  -- 4-hour wait for moderate reorgs
  | jtOrphanedBlocks jetski >= 5 = 100.0   -- 2-hour wait for minor reorgs
  | otherwise = 10.0  -- Standard 10 confirmations

-- | Defensive adoption rate influenced by attack frequency
defenseAdoptionByThreat :: JetskiTrackerData -> Double
defenseAdoptionByThreat jetski
  | jtBlockWithholdingScore jetski > 0.85 = 0.9  -- Emergency adoption
  | jtBlockWithholdingScore jetski > 0.6 = 0.5   -- Moderate adoption
  | otherwise = 0.1  -- Minimal adoption

-- ========================================================================
-- LIVE DATA-INFORMED EQUILIBRIUM STRATEGY
-- ========================================================================

-- | Qubic attack strategy enhanced with Jetski real-time monitoring
qubicAttackStrategyLive :: JetskiTrackerData
                        -> Kleisli Stochastic () (List '[Double, Double, Double, Double,
                                                          Double, Double, Double, Double])
qubicAttackStrategyLive jetski =
  supplierCompetitivePricing ::-
  honestMaxStrategy ::-
  (\_ _ -> playDeterministically $ selfishAdaptiveStrategy jetski) ::-
  (\_ _ -> playDeterministically $ selfishAdaptiveStrategy jetski) ::-
  (\_ _ -> playDeterministically $ if jtQubicHashrate jetski / jtNetworkHashrate jetski > 0.51
                                    then 0.51 else 0.45) ::-
  (\_ _ -> playDeterministically $ attackDurationByReorgHistory jetski) ::-
  (\_ _ -> playDeterministically $ exchangeConfirmationPolicy jetski) ::-
  (\_ _ -> playDeterministically $ defenseAdoptionByThreat jetski) ::-
  Nil

-- | Post-defense equilibrium with live threat monitoring
postDefenseEquilibriumLive :: JetskiTrackerData
                           -> Kleisli Stochastic () (List '[Double, Double, Double, Double,
                                                            Double, Double, Double, Double])
postDefenseEquilibriumLive jetski =
  supplierCompetitivePricing ::-
  honestMaxStrategy ::-
  (\_ _ -> playDeterministically 0.0) ::-  -- No selfish mining when detective active
  (\_ _ -> playDeterministically 0.0) ::-
  (\_ _ -> playDeterministically 0.0) ::-
  (\_ _ -> playDeterministically 0.0) ::-
  (\_ _ -> playDeterministically $ min 200.0 (exchangeConfirmationPolicy jetski)) ::-
  (\_ _ -> playDeterministically $ max 0.75 (defenseAdoptionByThreat jetski)) ::-
  Nil

-- ========================================================================
-- ANALYSIS WITH LIVE DATA REFRESH
-- ========================================================================

-- | Run analysis with periodic Jetski data updates
runLiveAnalysis :: MoneroContextLive -> IO ()
runLiveAnalysis ctx = do
  putStrLn "🔴 LIVE MONERO RENTAL HASH WAR ANALYSIS"
  putStrLn "=" <> replicate 70 '='
  putStrLn $ "📊 Data source: https://explorer.jetskipool.ai/xmr-tracker"
  putStrLn ""

  -- Fetch fresh data
  liveData <- fetchJetskiTrackerData
  let updatedCtx = ctx { jetskiData = liveData }

  -- Display current threat level
  putStrLn "🎯 CURRENT NETWORK STATE"
  putStrLn $ "   Network hashrate: " ++ show (jtNetworkHashrate liveData) ++ " GH/s"
  putStrLn $ "   Qubic hashrate: " ++ show (jtQubicHashrate liveData) ++ " GH/s"
  putStrLn $ "   Qubic share: " ++ show (round $ jtQubicHashrate liveData / jtNetworkHashrate liveData * 100) ++ "%"
  putStrLn $ "   Orphaned blocks (24h): " ++ show (jtOrphanedBlocks liveData)
  putStrLn $ "   Block withholding score: " ++ show (jtBlockWithholdingScore liveData)
  putStrLn $ "   Last reorg depth: " ++ show (jtLastReorgDepth liveData)
  putStrLn $ "   XMR price: $" ++ show (jtXMRPrice liveData)
  putStrLn ""

  -- Threat assessment
  let threatLevel = case () of
        _ | jtBlockWithholdingScore liveData > 0.85 -> "🔴 CRITICAL"
        _ | jtBlockWithholdingScore liveData > 0.6 -> "🟠 HIGH"
        _ | jtBlockWithholdingScore liveData > 0.3 -> "🟡 MODERATE"
        _ -> "🟢 LOW"

  putStrLn $ "⚠️  THREAT LEVEL: " ++ threatLevel
  putStrLn ""

  -- Defensive recommendations
  putStrLn "🛡️  RECOMMENDED DEFENSIVE POSTURE"
  putStrLn $ "   Exchange confirmations: " ++ show (round $ exchangeConfirmationPolicy liveData)
  putStrLn $ "   Detective mining adoption: " ++ show (round $ defenseAdoptionByThreat liveData * 100) ++ "%"
  putStrLn $ "   Recommended rental monitoring: " ++
    if jtBlockWithholdingScore liveData > 0.7 then "CONTINUOUS" else "HOURLY"
  putStrLn ""

  -- Strategy analysis
  when (jtBlockWithholdingScore liveData > 0.7) $ do
    putStrLn "🚨 ACTIVE ATTACK DETECTED"
    putStrLn "   Selfish mining probability: HIGH"
    putStrLn "   Recommended action: Increase confirmations to 720"
    putStrLn "   Expected double-spend risk: ELEVATED"
    putStrLn ""

  -- Pool distribution
  putStrLn "🎲 POOL DISTRIBUTION"
  mapM_ (\(pool, share) ->
    putStrLn $ "   " ++ pool ++ ": " ++ show (round $ share * 100) ++ "%"
    ) (jtPoolDistribution liveData)
  putStrLn ""

  -- Equilibrium prediction
  let currentEquilibrium
        | jtBlockWithholdingScore liveData > 0.7 = "QUBIC ATTACK ACTIVE"
        | jtOrphanedBlocks liveData > 10 = "POST-ATTACK RECOVERY"
        | otherwise = "HONEST MINING STABLE"

  putStrLn $ "⚖️  PREDICTED EQUILIBRIUM: " ++ currentEquilibrium
  putStrLn ""
  putStrLn "=" <> replicate 70 '='

-- | Main entry point with live data monitoring
main :: IO ()
main = do
  putStrLn "🎮 Monero Rental Hash War - Live Data Edition"
  putStrLn "Integrating https://explorer.jetskipool.ai/xmr-tracker"
  putStrLn ""

  -- Fetch initial Jetski data
  jetskiData <- fetchJetskiTrackerData

  -- Initialize context with live data
  let ctx = initialContextMoneroLive
              5.0    -- Base network hashrate (will be overridden by live data)
              100.0  -- Rental price per GH/day
              0.6    -- Block reward (XMR)
              10.0   -- Initial confirmation depth
              3.0    -- Qubic multiplier
              0.0    -- Initial detective adoption
              300.0  -- Exchange volume
              10000.0  -- Double-spend target
              50.0   -- Infrastructure cost
              jetskiData

  -- Run live analysis
  runLiveAnalysis ctx

  putStrLn ""
  putStrLn "💡 TIP: In production, this would refresh every 60 seconds"
  putStrLn "    with live data from Jetski Pool XMR tracker API"
  putStrLn ""
  putStrLn "◇ ♢ ◈ Real-time compositional adversarial game analysis ◈ ♢ ◇"
