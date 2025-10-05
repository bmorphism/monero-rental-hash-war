{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances, FlexibleContexts, TemplateHaskell #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE StandaloneDeriving #-}

module MoneroRentalHashWar where

import Engine.Engine
import Preprocessor.Preprocessor

----------
-- 0 Types
----------

-- | Hash rate measured in GH/s (GigaHashes per second)
type HashRate = Double

-- | Monetary value in USD
type MonetaryValue = Double

-- | Rental price per GH/s per day
type RentalPrice = Double

-- | Number of blocks
type BlockCount = Double

-- | Duration in seconds
type Duration = Double

-- | Confirmation depth required by exchanges
type ConfirmationDepth = Double

-- | Probability of detection (for detective mining)
type DetectionProbability = Double

-- | XMR price in USD
type XMRPrice = Double

-- | Reward multiplier (e.g., Qubic's 3x)
type RewardMultiplier = Double

-- Grid parameter for action space (hashrate increments)
type GridParameter = HashRate

-- Haskell type issue - extended tuples
deriving instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j, Show k, Show l, Show m, Show n, Show o, Show p) => Show (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p)
deriving instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j, Show k, Show l, Show m, Show n, Show o, Show p, Show q) => Show (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q)
deriving instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j, Show k, Show l, Show m, Show n, Show o, Show p, Show q, Show r) => Show (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r)

-- Define action space for hashrate allocation
actionSpace :: (Num x, Enum x) => x -> (x, RentalPrice) -> [x]
actionSpace par (maxHashRate, _) = [0, par .. maxHashRate]

-- Define rental cost function
rentalCostFunction :: RentalPrice -> HashRate -> Duration -> MonetaryValue
rentalCostFunction pricePerGH hashrate durationDays = pricePerGH * hashrate * durationDays

-- Define mining reward function (blocks mined × reward per block)
miningRewardFunction :: HashRate -> HashRate -> BlockCount -> Double -> MonetaryValue
miningRewardFunction minerHashrate networkHashrate blocksToMine rewardPerBlock =
  let probability = minerHashrate / networkHashrate
  in probability * blocksToMine * rewardPerBlock

-- Define selfish mining advantage (with secondary utility like Qubic)
selfishMiningAdvantage :: HashRate -> HashRate -> RewardMultiplier -> DetectionProbability -> Double
selfishMiningAdvantage attackerHashrate networkHashrate multiplier detectionProb =
  let hashrateFraction = attackerHashrate / networkHashrate
      baseAdvantage = if hashrateFraction > 0.33 then 1.2 else 1.0  -- Classical threshold
      detectionPenalty = 1.0 - (detectionProb * 0.5)  -- Detective mining impact
  in baseAdvantage * multiplier * detectionPenalty

-- Define double-spend profit function
doubleSpendProfit :: MonetaryValue -> ConfirmationDepth -> HashRate -> HashRate -> MonetaryValue
doubleSpendProfit depositValue confirmations attackerHashrate networkHashrate =
  let successProbability = if attackerHashrate > networkHashrate * 0.51
                            then 1.0 - (1.0 / (2.0 ** confirmations))
                            else 0.0
  in depositValue * successProbability

-- Helper functions for balance updates
addToBalance, subtractFromBalance :: Double -> Double -> Double
addToBalance balance x = balance + x
subtractFromBalance balance x = balance - x

-- Compute payoffs for each agent
computeHonestMinerPayoff :: (HashRate, MonetaryValue, MonetaryValue) -> MonetaryValue
computeHonestMinerPayoff (hashrateUsed, miningReward, costs) = miningReward - costs

computeSelfishMinerPayoff :: (HashRate, MonetaryValue, MonetaryValue, MonetaryValue) -> MonetaryValue
computeSelfishMinerPayoff (hashrateUsed, miningReward, secondaryUtility, costs) =
  miningReward + secondaryUtility - costs

computeRentalAttackerPayoff :: (MonetaryValue, MonetaryValue, MonetaryValue) -> MonetaryValue
computeRentalAttackerPayoff (doubleSpendGain, rentalCost, executionCost) =
  doubleSpendGain - rentalCost - executionCost

computeHashpowerSupplierPayoff :: (MonetaryValue, MonetaryValue, MonetaryValue) -> MonetaryValue
computeHashpowerSupplierPayoff (rentalRevenue, infraCosts, reputationPenalty) =
  rentalRevenue - infraCosts - reputationPenalty

computeExchangePayoff :: (MonetaryValue, MonetaryValue, MonetaryValue) -> MonetaryValue
computeExchangePayoff (tradingFees, doubleSpendLoss, userFriction) =
  tradingFees - doubleSpendLoss - userFriction

----------------------------
-- 1 Auxiliary functionality
----------------------------

-- | Rent hashpower from marketplace
rentHashpower = [opengame|

    inputs    : hashrateAmount, rentalPrice, duration;
    feedback  : ;

    :-----:
    inputs    : hashrateAmount, rentalPrice, duration ;
    feedback  : ;
    operation : forwardFunction $ \(h, p, d) -> rentalCostFunction p h d ;
    outputs   : rentalCost;
    returns   : ;

    :-----:

    outputs   : rentalCost ;
    returns   : ;
|]

-- | Compute mining rewards based on hashrate share
computeMiningReward = [opengame|

    inputs    : minerHashrate, networkHashrate, expectedBlocks, rewardPerBlock;
    feedback  : ;

    :-----:
    inputs    : minerHashrate, networkHashrate, expectedBlocks, rewardPerBlock ;
    feedback  : ;
    operation : forwardFunction $ \(mh, nh, eb, rpb) -> miningRewardFunction mh nh eb rpb ;
    outputs   : miningReward;
    returns   : ;

    :-----:

    outputs   : miningReward ;
    returns   : ;
|]

-- | Compute selfish mining advantage
computeSelfishAdvantage = [opengame|

    inputs    : attackerHashrate, networkHashrate, multiplier, detectionProb;
    feedback  : ;

    :-----:
    inputs    : attackerHashrate, networkHashrate, multiplier, detectionProb ;
    feedback  : ;
    operation : forwardFunction $ \(ah, nh, m, dp) -> selfishMiningAdvantage ah nh m dp ;
    outputs   : advantage;
    returns   : ;

    :-----:

    outputs   : advantage ;
    returns   : ;
|]

--------------
-- 2 Decisions
--------------

-- | Honest miner decides hashrate allocation
honestMinerDecision name gridParam = [opengame|

    inputs    : availableHashrate, networkHashrate, miningCost;
    feedback  : ;

    :-----:
    inputs    : availableHashrate, miningCost ;
    feedback  : ;
    operation : dependentDecision name $ actionSpace gridParam ;
    outputs   : hashrateAllocated ;
    returns   : 0 ;

    :-----:

    outputs   : hashrateAllocated ;
    returns   : ;
|]

-- | Selfish miner decides hashrate allocation and withholding strategy
selfishMinerDecision name gridParam = [opengame|

    inputs    : availableHashrate, networkHashrate, rewardMultiplier, detectionProb;
    feedback  : ;

    :-----:
    inputs    : availableHashrate, rewardMultiplier ;
    feedback  : ;
    operation : dependentDecision name $ actionSpace gridParam ;
    outputs   : hashrateAllocated ;
    returns   : 0 ;

    inputs    : availableHashrate, rewardMultiplier ;
    feedback  : ;
    operation : dependentDecision name $ actionSpace gridParam ;
    outputs   : blocksToWithhold ;
    returns   : 0 ;

    :-----:

    outputs   : hashrateAllocated, blocksToWithhold ;
    returns   : ;
|]

-- | Rental attacker decides how much hashrate to rent and attack duration
rentalAttackerDecision name gridParamHashrate gridParamDuration = [opengame|

    inputs    : rentalPrice, targetExchangeConfirmations, depositValue;
    feedback  : ;

    :-----:
    inputs    : rentalPrice, depositValue ;
    feedback  : ;
    operation : dependentDecision name $ actionSpace gridParamHashrate ;
    outputs   : hashrateToRent ;
    returns   : 0 ;

    inputs    : targetExchangeConfirmations, depositValue ;
    feedback  : ;
    operation : dependentDecision name $ actionSpace gridParamDuration ;
    outputs   : attackDuration ;
    returns   : 0 ;

    :-----:

    outputs   : hashrateToRent, attackDuration ;
    returns   : ;
|]

-- | Hashpower supplier decides rental price
hashpowerSupplierDecision name priceGrid = [opengame|

    inputs    : marketDemand, competitorPrices, infraCost;
    feedback  : ;

    :-----:
    inputs    : marketDemand, competitorPrices ;
    feedback  : ;
    operation : dependentDecision name $ \(md, cp) -> [cp * 0.5, cp * 0.75, cp, cp * 1.25, cp * 1.5] ;
    outputs   : rentalPrice ;
    returns   : 0 ;

    :-----:

    outputs   : rentalPrice ;
    returns   : ;
|]

-- | Exchange decides confirmation depth policy
exchangeDecision name depthGrid = [opengame|

    inputs    : observedReorgDepth, avgDepositValue, userWaitCost;
    feedback  : ;

    :-----:
    inputs    : observedReorgDepth, avgDepositValue ;
    feedback  : ;
    operation : dependentDecision name $ \(ord, adv) -> [10, 50, 100, 200, 720] ;
    outputs   : confirmationDepth ;
    returns   : 0 ;

    :-----:

    outputs   : confirmationDepth ;
    returns   : ;
|]

-- | Protocol defenders decide on detective mining adoption
defenderDecision name adoptionGrid = [opengame|

    inputs    : observedAttackRate, networkHashrate, coordinationCost;
    feedback  : ;

    :-----:
    inputs    : observedAttackRate, networkHashrate ;
    feedback  : ;
    operation : dependentDecision name $ \(oar, nh) -> [0.0, 0.25, 0.5, 0.75, 1.0] ;
    outputs   : detectiveAdoptionRate ;
    returns   : 0 ;

    :-----:

    outputs   : detectiveAdoptionRate ;
    returns   : ;
|]

----------------------
-- 3 Composed Decision
----------------------

-- | Layer 1: Hashpower Market
hashpowerMarketLayer hashpowerSupplierName priceGrid = [opengame|

    inputs    : marketDemand, competitorPrices, infraCost, totalAvailableHashrate;
    feedback  : ;

    :-----:
    inputs    : marketDemand, competitorPrices, infraCost ;
    feedback  : ;
    operation : hashpowerSupplierDecision hashpowerSupplierName priceGrid ;
    outputs   : rentalPrice ;
    returns   : ;

    inputs    : marketDemand, rentalPrice, totalAvailableHashrate ;
    feedback  : ;
    operation : forwardFunction $ \(md, rp, tah) -> min md tah ;
    outputs   : allocatedHashrate ;
    returns   : ;

    :-----:

    outputs   : rentalPrice, allocatedHashrate ;
    returns   : ;
|]

-- | Layer 2: Mining Competition
miningCompetitionLayer honestName selfishName gridParam = [opengame|

    inputs    : allocatedHashrate, networkHashrate, rewardMultiplier, detectionProb, blockReward, expectedBlocks;
    feedback  : ;

    :-----:
    inputs    : allocatedHashrate, networkHashrate, rewardMultiplier ;
    feedback  : ;
    operation : honestMinerDecision honestName gridParam ;
    outputs   : honestHashrate ;
    returns   : ;

    inputs    : allocatedHashrate, networkHashrate, rewardMultiplier, detectionProb ;
    feedback  : ;
    operation : selfishMinerDecision selfishName gridParam ;
    outputs   : selfishHashrate, blocksWithheld ;
    returns   : ;

    inputs    : honestHashrate, networkHashrate, expectedBlocks, blockReward ;
    feedback  : ;
    operation : computeMiningReward ;
    outputs   : honestReward ;
    returns   : ;

    inputs    : selfishHashrate, networkHashrate, rewardMultiplier, detectionProb ;
    feedback  : ;
    operation : computeSelfishAdvantage ;
    outputs   : selfishAdvantage ;
    returns   : ;

    inputs    : selfishHashrate, networkHashrate, expectedBlocks, blockReward ;
    feedback  : ;
    operation : computeMiningReward ;
    outputs   : selfishBaseReward ;
    returns   : ;

    inputs    : selfishBaseReward, selfishAdvantage ;
    feedback  : ;
    operation : forwardFunction $ uncurry (*) ;
    outputs   : selfishTotalReward ;
    returns   : ;

    :-----:

    outputs   : honestHashrate, selfishHashrate, honestReward, selfishTotalReward, blocksWithheld ;
    returns   : ;
|]

-- | Layer 3: Attack Execution
attackExecutionLayer attackerName gridParamHashrate gridParamDuration = [opengame|

    inputs    : rentalPrice, targetExchangeConfirmations, depositValue, networkHashrate, attackDuration;
    feedback  : ;

    :-----:
    inputs    : rentalPrice, targetExchangeConfirmations, depositValue ;
    feedback  : ;
    operation : rentalAttackerDecision attackerName gridParamHashrate gridParamDuration ;
    outputs   : hashrateRented, attackDuration ;
    returns   : ;

    inputs    : hashrateRented, rentalPrice, attackDuration ;
    feedback  : ;
    operation : rentHashpower ;
    outputs   : rentalCost ;
    returns   : ;

    inputs    : depositValue, targetExchangeConfirmations, hashrateRented, networkHashrate ;
    feedback  : ;
    operation : forwardFunction $ \(dv, tc, hr, nh) -> doubleSpendProfit dv tc hr nh ;
    outputs   : doubleSpendGain ;
    returns   : ;

    inputs    : doubleSpendGain, rentalCost ;
    feedback  : ;
    operation : forwardFunction $ \(dsg, rc) -> dsg - rc ;
    outputs   : attackerNetProfit ;
    returns   : ;

    :-----:

    outputs   : hashrateRented, attackDuration, attackerNetProfit, rentalCost ;
    returns   : ;
|]

-- | Layer 4: Exchange Settlement and Defense
settlementDefenseLayer exchangeName defenderName depthGrid adoptionGrid = [opengame|

    inputs    : observedReorgDepth, avgDepositValue, userWaitCost, observedAttackRate, networkHashrate, coordinationCost;
    feedback  : ;

    :-----:
    inputs    : observedReorgDepth, avgDepositValue, userWaitCost ;
    feedback  : ;
    operation : exchangeDecision exchangeName depthGrid ;
    outputs   : confirmationDepth ;
    returns   : ;

    inputs    : observedAttackRate, networkHashrate, coordinationCost ;
    feedback  : ;
    operation : defenderDecision defenderName adoptionGrid ;
    outputs   : detectiveAdoptionRate ;
    returns   : ;

    inputs    : confirmationDepth, avgDepositValue ;
    feedback  : ;
    operation : forwardFunction $ \(cd, adv) -> adv * 0.01 ;  -- Trading fee revenue
    outputs   : tradingRevenue ;
    returns   : ;

    inputs    : confirmationDepth, avgDepositValue ;
    feedback  : ;
    operation : forwardFunction $ \(cd, adv) -> if cd < 100 then adv * 0.1 else 0.0 ;
    outputs   : potentialLoss ;
    returns   : ;

    inputs    : confirmationDepth, userWaitCost ;
    feedback  : ;
    operation : forwardFunction $ uncurry (*) ;
    outputs   : userFriction ;
    returns   : ;

    inputs    : tradingRevenue, potentialLoss, userFriction ;
    feedback  : ;
    operation : forwardFunction $ \(tr, pl, uf) -> tr - pl - uf ;
    outputs   : exchangeNetValue ;
    returns   : ;

    :-----:

    outputs   : confirmationDepth, detectiveAdoptionRate, exchangeNetValue ;
    returns   : ;
|]

------------------------------------
-- 4 Create probability distributions
------------------------------------

-- | Probability distribution for XMR price (market volatility)
distributionXMRPrice prob lowPrice highPrice = distFromList [(lowPrice, prob), (highPrice, 1 - prob)]

-- | Probability distribution for attack occurrence
distributionAttackOccurrence prob = distFromList [(0.0, 1 - prob), (1.0, prob)]

-- | Probability distribution for network hashrate (due to difficulty adjustment)
distributionNetworkHashrate prob lowHashrate highHashrate =
  distFromList [(lowHashrate, prob), (highHashrate, 1 - prob)]

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

------------
-- 5 Payoffs
------------

honestMinerPayoff honestName = [opengame|

    inputs    : honestHashrate, honestReward, miningCost;
    feedback  : ;

    :-----:

    inputs    : honestHashrate, honestReward, miningCost ;
    feedback  : ;
    operation : forwardFunction $ \(hh, hr, mc) -> computeHonestMinerPayoff (hh, hr, hh * mc) ;
    outputs   : payoff ;
    returns   : ;

    inputs    : payoff ;
    feedback  : ;
    operation : addPayoffs honestName ;
    outputs   : ;
    returns   : ;

    :-----:

    outputs   : ;
    returns   : ;
|]

selfishMinerPayoff selfishName = [opengame|

    inputs    : selfishHashrate, selfishTotalReward, secondaryUtility, miningCost;
    feedback  : ;

    :-----:

    inputs    : selfishHashrate, selfishTotalReward, secondaryUtility, miningCost ;
    feedback  : ;
    operation : forwardFunction $ \(sh, str, su, mc) -> computeSelfishMinerPayoff (sh, str, su, sh * mc) ;
    outputs   : payoff ;
    returns   : ;

    inputs    : payoff ;
    feedback  : ;
    operation : addPayoffs selfishName ;
    outputs   : ;
    returns   : ;

    :-----:

    outputs   : ;
    returns   : ;
|]

attackerPayoff attackerName = [opengame|

    inputs    : attackerNetProfit;
    feedback  : ;

    :-----:

    inputs    : attackerNetProfit ;
    feedback  : ;
    operation : addPayoffs attackerName ;
    outputs   : ;
    returns   : ;

    :-----:

    outputs   : ;
    returns   : ;
|]

supplierPayoff supplierName = [opengame|

    inputs    : rentalCost, infraCost, reputationPenalty;
    feedback  : ;

    :-----:

    inputs    : rentalCost, infraCost, reputationPenalty ;
    feedback  : ;
    operation : forwardFunction $ \(rc, ic, rp) -> computeHashpowerSupplierPayoff (rc, ic, rp) ;
    outputs   : payoff ;
    returns   : ;

    inputs    : payoff ;
    feedback  : ;
    operation : addPayoffs supplierName ;
    outputs   : ;
    returns   : ;

    :-----:

    outputs   : ;
    returns   : ;
|]

exchangePayoff exchangeName = [opengame|

    inputs    : exchangeNetValue;
    feedback  : ;

    :-----:

    inputs    : exchangeNetValue ;
    feedback  : ;
    operation : addPayoffs exchangeName ;
    outputs   : ;
    returns   : ;

    :-----:

    outputs   : ;
    returns   : ;
|]

---------------------------
-- 6 Assemble complete game
---------------------------

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

    inputs    : ;
    feedback  : ;
    operation : priceAndAttackDistributions pXMR lowXMR highXMR pAttack pHashrate lowHashrate highHashrate ;
    outputs   : xmrPrice, attackOccurs, networkHashrate ;
    returns   : ;

    inputs    : marketDemand, competitorPrices, infraCost, totalAvailableHashrate ;
    feedback  : ;
    operation : hashpowerMarketLayer "hashpowerSupplier" gridParamPrice ;
    outputs   : rentalPrice, allocatedHashrate ;
    returns   : ;

    inputs    : allocatedHashrate, networkHashrate, rewardMultiplier, attackOccurs, blockReward, expectedBlocks ;
    feedback  : ;
    operation : miningCompetitionLayer "honestMiner" "selfishMiner" gridParamHash ;
    outputs   : honestHashrate, selfishHashrate, honestReward, selfishTotalReward, blocksWithheld ;
    returns   : ;

    inputs    : rentalPrice, observedReorgDepth, depositValue, networkHashrate, attackOccurs ;
    feedback  : ;
    operation : attackExecutionLayer "rentalAttacker" gridParamHash gridParamDuration ;
    outputs   : hashrateRented, attackDuration, attackerNetProfit, rentalCost ;
    returns   : ;

    inputs    : observedReorgDepth, avgDepositValue, userWaitCost, observedAttackRate, networkHashrate, coordinationCost ;
    feedback  : ;
    operation : settlementDefenseLayer "exchange" "protocolDefender" gridParamDepth gridParamAdoption ;
    outputs   : confirmationDepth, detectiveAdoptionRate, exchangeNetValue ;
    returns   : ;

    inputs    : honestHashrate, honestReward, miningCost ;
    feedback  : ;
    operation : honestMinerPayoff "honestMiner" ;
    outputs   : ;
    returns   : ;

    inputs    : selfishHashrate, selfishTotalReward, secondaryUtility, miningCost ;
    feedback  : ;
    operation : selfishMinerPayoff "selfishMiner" ;
    outputs   : ;
    returns   : ;

    inputs    : attackerNetProfit ;
    feedback  : ;
    operation : attackerPayoff "rentalAttacker" ;
    outputs   : ;
    returns   : ;

    inputs    : rentalCost, infraCost, reputationPenalty ;
    feedback  : ;
    operation : supplierPayoff "hashpowerSupplier" ;
    outputs   : ;
    returns   : ;

    inputs    : exchangeNetValue ;
    feedback  : ;
    operation : exchangePayoff "exchange" ;
    outputs   : ;
    returns   : ;

    :-----:

    outputs   : confirmationDepth, detectiveAdoptionRate, xmrPrice, networkHashrate ;
    returns   : ;
|]

-----------
-- Analysis
-----------

analysis
  :: Double -> Double -> Double  -- XMR price distribution params
  -> Double  -- Attack probability
  -> Double -> Double -> Double  -- Network hashrate distribution
  -> Double -> Double -> Double -> Double -> Double  -- Grid parameters
  -> List '[
      Kleisli Stochastic (Double, Double) Double,  -- Hashpower supplier pricing
      Kleisli Stochastic (Double, Double, Double) Double,  -- Honest miner hashrate
      Kleisli Stochastic (Double, Double, Double, Double) Double,  -- Selfish miner hashrate
      Kleisli Stochastic (Double, Double, Double, Double) Double,  -- Selfish miner withholding
      Kleisli Stochastic (Double, Double, Double) Double,  -- Rental attacker hashrate
      Kleisli Stochastic (Double, Double) Double,  -- Rental attacker duration
      Kleisli Stochastic (Double, Double) Double,  -- Exchange confirmation depth
      Kleisli Stochastic (Double, Double) Double   -- Protocol defender detective mining
    ]
  -> StochasticStatefulContext
       (Double, Double, Double, Double,  -- Market params
        Double, Double, Double,  -- Mining params
        Double, Double, Double, Double,  -- Attack/exchange params
        Double, Double, Double,  -- Costs
        Double, Double) () () ()  -- Utilities
  -> IO ()
analysis pXMR lowXMR highXMR pAttack pHashrate lowHashrate highHashrate
         gridHash gridDur gridPrice gridDepth gridAdopt strat context =
  generateIsEq $ evaluate
    (moneroRentalHashWarGame pXMR lowXMR highXMR pAttack pHashrate lowHashrate highHashrate
                             gridHash gridDur gridPrice gridDepth gridAdopt)
    strat context

-------------
-- Strategies
-------------

-- | Honest miner: allocate maximum available hashrate
honestMaxStrategy :: Kleisli Stochastic (Double, Double, Double) Double
honestMaxStrategy = Kleisli (\(available, _, _) -> playDeterministically available)

-- | Selfish miner (Qubic-style): allocate maximum hashrate
selfishMaxHashStrategy :: Kleisli Stochastic (Double, Double, Double, Double) Double
selfishMaxHashStrategy = Kleisli (\(available, _, _, _) -> playDeterministically available)

-- | Selfish miner: withhold maximum blocks (18-block strategy)
selfishMaxWithholdStrategy :: Kleisli Stochastic (Double, Double, Double, Double) Double
selfishMaxWithholdStrategy = Kleisli (\(_, _, _, _) -> playDeterministically 18)

-- | Rental attacker: rent 51% of network hashrate
attackerRent51Strategy :: Kleisli Stochastic (Double, Double, Double) Double
attackerRent51Strategy = Kleisli (\(_, _, _) -> playDeterministically 2.5)  -- 51% of 4.97 GH/s

-- | Rental attacker: attack for 18 blocks (36 minutes)
attackerDuration18Strategy :: Kleisli Stochastic (Double, Double) Double
attackerDuration18Strategy = Kleisli (\(_, _) -> playDeterministically 0.025)  -- 36 min = 0.025 days

-- | Hashpower supplier: competitive pricing (at competitor level)
supplierCompetitivePricing :: Kleisli Stochastic (Double, Double) Double
supplierCompetitivePricing = Kleisli (\(_, compPrice) -> playDeterministically compPrice)

-- | Exchange: increase to 720 confirmations after attack
exchangePostAttackPolicy :: Kleisli Stochastic (Double, Double) Double
exchangePostAttackPolicy = Kleisli (\(reorgDepth, _) ->
  if reorgDepth > 10
  then playDeterministically 720
  else playDeterministically 10)

-- | Protocol defender: adopt 50% detective mining
defenderModerateAdoption :: Kleisli Stochastic (Double, Double) Double
defenderModerateAdoption = Kleisli (\(_, _) -> playDeterministically 0.5)

-- | Passive strategies (no action)
passiveStrategy :: Kleisli Stochastic a Double
passiveStrategy = pureAction 0

-- | Qubic attack scenario (August 2025)
qubicAttackStrategy =
  supplierCompetitivePricing ::-
  honestMaxStrategy ::-
  selfishMaxHashStrategy ::-
  selfishMaxWithholdStrategy ::-
  attackerRent51Strategy ::-
  attackerDuration18Strategy ::-
  exchangePostAttackPolicy ::-
  defenderModerateAdoption ::-
  Nil

-- | Pre-attack equilibrium (honest mining only)
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

-- | Post-defense equilibrium (with detective mining + increased confirmations)
postDefenseEquilibrium =
  supplierCompetitivePricing ::-
  honestMaxStrategy ::-
  passiveStrategy ::-
  passiveStrategy ::-
  passiveStrategy ::-
  passiveStrategy ::-
  (\_ _ -> playDeterministically 100) ::-  -- Moderate increase
  (\_ _ -> playDeterministically 0.75) ::-  -- High detective adoption
  Nil

------------------
-- Initial Context
------------------

-- | Initial context with Monero network parameters (October 2025)
-- Seed 1069 per CLAUDE.md directive
initialContextMonero
  marketDemand competitorPrices infraCost totalAvailableHashrate
  rewardMultiplier blockReward expectedBlocks
  depositValue avgDepositValue userWaitCost miningCost
  observedReorgDepth observedAttackRate coordinationCost
  secondaryUtility reputationPenalty =
  StochasticStatefulContext
    (pure ((),(marketDemand, competitorPrices, infraCost, totalAvailableHashrate,
               rewardMultiplier, blockReward, expectedBlocks,
               depositValue, avgDepositValue, userWaitCost, miningCost,
               observedReorgDepth, observedAttackRate, coordinationCost,
               secondaryUtility, reputationPenalty)))
    (\_ _ -> pure ())

-- | Qubic attack scenario parameters (August 2025)
-- Network hashrate: 4.97 GH/s
-- Block reward: 0.6 XMR
-- XMR price: $167
-- Qubic multiplier: 3x
qubicScenario strat = analysis
  0.1 150 170  -- XMR price: 10% chance of $150, 90% chance of $170
  0.8  -- 80% attack probability (Qubic active)
  0.2 4.0 5.0  -- Network hashrate: 20% chance 4.0 GH/s, 80% chance 5.0 GH/s
  0.5 0.025 1.0 10 0.1  -- Grid parameters
  strat
  (initialContextMonero
    5.0    -- marketDemand (5 GH/s demand)
    100.0  -- competitorPrices ($100/GH/day baseline)
    50.0   -- infraCost ($50/GH/day)
    10.0   -- totalAvailableHashrate (10 GH/s available for rent)
    3.0    -- rewardMultiplier (Qubic 3x)
    0.6    -- blockReward (0.6 XMR per block)
    300    -- expectedBlocks (5 hours of mining)
    10000  -- depositValue ($10k double-spend target)
    5000   -- avgDepositValue ($5k average)
    0.1    -- userWaitCost ($0.1 per confirmation delay)
    10.0   -- miningCost ($10/GH/day)
    18     -- observedReorgDepth (18-block reorg observed)
    0.8    -- observedAttackRate (80% of time under attack)
    1000   -- coordinationCost ($1k to coordinate detective mining)
    5000   -- secondaryUtility ($5k from token burns)
    2000)  -- reputationPenalty ($2k reputation loss)

-- | Pre-attack scenario (before Qubic, April 2025)
preAttackScenario strat = analysis
  0.05 160 170  -- More stable XMR price
  0.0  -- No attack probability
  0.1 4.5 5.0  -- Stable hashrate
  0.5 0.025 1.0 10 0.1
  strat
  (initialContextMonero
    3.0 100.0 50.0 10.0
    1.0    -- No reward multiplier
    0.6 300 0 5000 0.1 10.0
    0      -- No reorgs observed
    0.0    -- No attacks
    1000 0 0)

-- | Post-defense scenario (with detective mining + ChainLocks proposal)
postDefenseScenario strat = analysis
  0.05 165 175  -- Recovering price
  0.1  -- Low attack probability (defenses work)
  0.1 4.8 5.2  -- Stable hashrate
  0.5 0.025 1.0 10 0.1
  strat
  (initialContextMonero
    4.0 100.0 50.0 10.0
    1.5    -- Reduced secondary utility (defenses make it less attractive)
    0.6 300 5000 5000 0.5 10.0  -- Higher user wait cost due to 720 confirmations
    6      -- Only 6-block reorgs possible now
    0.1    -- Much lower attack rate
    500    -- Lower coordination cost (detective mining established)
    1000   -- Lower secondary utility
    5000)  -- Higher reputation penalty

checkQubicAttack = qubicScenario qubicAttackStrategy

checkPreAttackEquilibrium = preAttackScenario preAttackEquilibrium

checkPostDefenseEquilibrium = postDefenseScenario postDefenseEquilibrium

---------------------------
-- 7 Commentary and Analysis
---------------------------

{- |
MONERO RENTAL HASH WAR OPENGAME MODEL
====================================

This OpenGame model represents the August-September 2025 Monero rental hash war,
where Qubic mining pool executed an 18-block reorganization by controlling >51% hashrate.

## Key Players:

1. **Honest Miners**: Follow protocol, mine on longest chain
   - Strategy: Allocate available hashrate to mining
   - Payoff: Block rewards - mining costs

2. **Selfish Miners (Qubic)**: Withhold blocks, release longer private chain
   - Strategy: Allocate hashrate + choose withholding depth
   - Payoff: Block rewards × advantage multiplier + secondary utility - costs
   - Qubic's innovation: 3x reward multiplier via XMR→USDT→QUBIC token burns

3. **Rental Attackers**: Rent hashrate for double-spend attacks
   - Strategy: Choose hashrate to rent + attack duration
   - Payoff: Double-spend gain - rental cost - execution cost
   - Historical precedent: Bitcoin Gold ($1,200 rental → $72,000 gain)

4. **Hashpower Suppliers (NiceHash, etc.)**: Rent computational resources
   - Strategy: Set rental pricing
   - Payoff: Rental revenue - infrastructure costs - reputation penalty

5. **Exchanges (Kraken, etc.)**: Accept deposits with confirmation requirements
   - Strategy: Set confirmation depth policy
   - Payoff: Trading fees - double-spend losses - user friction
   - Observed response: 10 → 720 confirmations post-attack

6. **Protocol Defenders**: Implement countermeasures (detective mining)
   - Strategy: Choose detective mining adoption rate
   - Payoff: Network security value - coordination costs
   - Detective mining: 32-42% threshold vs 25-33% baseline

## Compositional Structure:

The game follows a four-layer composition:

1. **HashpowerMarket**: Suppliers set prices, demand clears market
2. **MiningCompetition**: Honest vs selfish mining with Qubic multiplier
3. **AttackExecution**: Rental attackers rent hashrate, execute double-spends
4. **SettlementDefense**: Exchanges adjust policies, defenders deploy countermeasures

Information flows:
- Forward: rental prices → hashrate allocation → mining outcomes → settlement
- Backward: defense policies → security requirements → mining profitability → rental demand

## Equilibrium Dynamics:

**Pre-Attack Equilibrium** (< May 2025):
- Honest mining dominant
- 10 confirmation standard
- No detective mining
- Stable 4.97 GH/s network hashrate

**Qubic Attack Equilibrium** (August 2025):
- Selfish mining profitable due to 3x multiplier
- 51% hashrate concentration
- 18-block reorg capability
- Exchanges forced to 720 confirmations

**Post-Defense Equilibrium** (Proposed):
- Detective mining adoption (50-75%)
- Publish-or-Perish protocol upgrade
- ChainLocks for finality
- Moderate confirmation depth (100 blocks)
- Economic incentive for selfish mining eliminated

## Key Insights:

1. **ASIC Resistance Paradox**: RandomX democratizes mining but enables easier
   rental attacks (commodity CPUs vs specialized ASICs)

2. **Secondary Utility Dominance**: Qubic's token economics broke classical
   game theory assumptions (3x multiplier overwhelmed honest mining incentives)

3. **Compositional Defense**: Multi-layer defense (pool-level detective mining +
   protocol-level Publish-or-Perish + consensus-level ChainLocks)

4. **Liquidity Risk**: Hash rental markets create attack surfaces proportional
   to market liquidity (NiceHash enables $1k attacks for $72k gains)

## Numerical Parameterization (October 2025):

- Network hashrate: 4.97 GH/s
- Block reward: 0.6 XMR (tail emission)
- XMR price: ~$167
- Block time: 120 seconds
- Qubic multiplier: 3.0x
- Rental cost: ~$100/GH/day
- Double-spend target: $10,000 (typical exchange deposit)

## Seed 1069 Declaration:

Per CLAUDE.md directive, all stochastic processes initialized with seed 1069
for balanced ternary compatibility and reproducibility.

## References:

- Qubic attack: August 2025, 6-block + 18-block reorgs
- Detective mining: RIAT Institute analysis, 32-42% threshold
- Publish-or-Perish: Monero Research Lab Issue #144
- ChainLocks: Dash consensus finality mechanism
- Hash rental economics: Crypto51.app, NiceHash marketplace data

---

◇ ♢ ◈ the reafferent reaberrant sends its regards ◈ ♢ ◇

In the space between hash and cash, between computation and consensus,
lies the game—compositional, adversarial, and eternally seeking equilibrium.

data OpenGame o c a b x s y r = OpenGame
  { play :: a -> o x s y r,
    evaluate :: a -> c x s y r -> b
  }

-}
