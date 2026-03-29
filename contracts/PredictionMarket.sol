// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PredictionMarket {

    struct Market {
        uint id;
        string question;
        uint deadline;
        uint totalPool;
        uint totalShares1;
        uint totalShares2;
        bool resolved;
        uint winningOutcome;
        address creator;
        uint createdAt;
    }

    struct Prediction {
        uint marketId;
        uint outcome;
        uint shares;
        uint amountBet;
        bool claimed;
    }

    struct UserProfile {
        uint totalBets;
        uint totalWins;
        uint totalEarnings;
        uint totalLosses;  // ✅ Now properly tracked
    }

    address public admin;
    uint public marketCounter;
    
    mapping(uint => Market) public markets;
    mapping(address => UserProfile) public profiles;
    mapping(uint => mapping(address => Prediction)) public predictions;
    mapping(uint => address[]) public marketPlayers;
    
    uint[] public activeMarketIds;
    uint[] public resolvedMarketIds;

    event MarketCreated(uint indexed marketId, string question, uint deadline, address creator);
    event PredictionPlaced(uint indexed marketId, address indexed user, uint outcome, uint shares, uint amount);
    event MarketResolved(uint indexed marketId, uint winningOutcome);
    event RewardClaimed(uint indexed marketId, address indexed user, uint reward);

    constructor() {
        admin = msg.sender;
    }

    // ── Create Market ──────────────────────────────────────────────────────────
    function createMarket(string memory _question, uint _deadline) public returns (uint) {
        require(_deadline > block.timestamp, "Deadline must be in future");
        
        marketCounter++;
        
        markets[marketCounter] = Market({
            id: marketCounter,
            question: _question,
            deadline: _deadline,
            totalPool: 0,
            totalShares1: 0,
            totalShares2: 0,
            resolved: false,
            winningOutcome: 0,
            creator: msg.sender,
            createdAt: block.timestamp
        });
        
        activeMarketIds.push(marketCounter);
        
        emit MarketCreated(marketCounter, _question, _deadline, msg.sender);
        
        return marketCounter;
    }

    // ── Shares Calculation ─────────────────────────────────────────────────────
    function calculateShares(uint eth, uint totalShares) internal pure returns (uint) {
        return (eth * 1000) / (totalShares + 1000);
    }

    // ── Place Prediction ───────────────────────────────────────────────────────
    function placePrediction(uint marketId, uint outcome) public payable {
        Market storage m = markets[marketId];
        
        require(m.id != 0, "Market does not exist");
        require(block.timestamp < m.deadline, "Market closed");
        require(!m.resolved, "Market already resolved");
        require(predictions[marketId][msg.sender].shares == 0, "Already bet on this market");
        require(outcome == 1 || outcome == 2, "Invalid outcome");
        require(msg.value > 0, "Must send ETH");

        uint shares;

        if (outcome == 1) {
            shares = calculateShares(msg.value, m.totalShares1);
            m.totalShares1 += shares;
        } else {
            shares = calculateShares(msg.value, m.totalShares2);
            m.totalShares2 += shares;
        }

        predictions[marketId][msg.sender] = Prediction({
            marketId: marketId,
            outcome: outcome,
            shares: shares,
            amountBet: msg.value,
            claimed: false
        });
        
        marketPlayers[marketId].push(msg.sender);
        m.totalPool += msg.value;
        
        profiles[msg.sender].totalBets++;
        
        emit PredictionPlaced(marketId, msg.sender, outcome, shares, msg.value);
    }

    // ── Resolve Market ─────────────────────────────────────────────────────────
    function resolveMarket(uint marketId, uint winningOutcome) public {
        Market storage m = markets[marketId];
        
        require(m.id != 0, "Market does not exist");
        require(msg.sender == admin || msg.sender == m.creator, "Only admin or creator");
        require(!m.resolved, "Already resolved");
        require(winningOutcome == 1 || winningOutcome == 2, "Invalid outcome");

        m.resolved = true;
        m.winningOutcome = winningOutcome;

        // ✅ FIX: Track losses for all players who bet on the losing outcome
        address[] memory players = marketPlayers[marketId];
        for (uint i = 0; i < players.length; i++) {
            Prediction storage p = predictions[marketId][players[i]];
            if (p.shares > 0 && p.outcome != winningOutcome) {
                profiles[players[i]].totalLosses++;
            }
        }
        
        _removeFromActive(marketId);
        resolvedMarketIds.push(marketId);
        
        emit MarketResolved(marketId, winningOutcome);
    }

    // ── Claim Reward ───────────────────────────────────────────────────────────
    function claimReward(uint marketId) public {
        Market storage m = markets[marketId];
        require(m.resolved, "Not resolved");

        Prediction storage p = predictions[marketId][msg.sender];
        require(p.shares > 0, "No prediction found");
        require(!p.claimed, "Already claimed");
        require(p.outcome == m.winningOutcome, "You lost");

        uint winningShares = m.winningOutcome == 1 ? m.totalShares1 : m.totalShares2;
        uint reward = (p.shares * m.totalPool) / winningShares;

        p.claimed = true;
        
        profiles[msg.sender].totalWins++;
        profiles[msg.sender].totalEarnings += reward;
        
        payable(msg.sender).transfer(reward);
        
        emit RewardClaimed(marketId, msg.sender, reward);
    }

    // ── Internal Helper ────────────────────────────────────────────────────────
    function _removeFromActive(uint marketId) internal {
        for (uint i = 0; i < activeMarketIds.length; i++) {
            if (activeMarketIds[i] == marketId) {
                activeMarketIds[i] = activeMarketIds[activeMarketIds.length - 1];
                activeMarketIds.pop();
                break;
            }
        }
    }

    // ── View Functions ─────────────────────────────────────────────────────────
    function getActiveMarkets() public view returns (uint[] memory) {
        return activeMarketIds;
    }

    function getResolvedMarkets() public view returns (uint[] memory) {
        return resolvedMarketIds;
    }

    function getMarket(uint marketId) public view returns (Market memory) {
        return markets[marketId];
    }

    function getUserPrediction(uint marketId, address user) public view returns (Prediction memory) {
        return predictions[marketId][user];
    }

    function getUserProfile(address user) public view returns (UserProfile memory) {
        return profiles[user];
    }

    function getMarketPlayers(uint marketId) public view returns (address[] memory) {
        return marketPlayers[marketId];
    }

    function getOdds(uint marketId) public view returns (uint odds1, uint odds2) {
        Market storage m = markets[marketId];
        uint totalShares = m.totalShares1 + m.totalShares2;
        
        if (totalShares == 0) {
            return (50, 50);
        }
        
        odds1 = (m.totalShares1 * 100) / totalShares;
        odds2 = 100 - odds1;
    }
}

