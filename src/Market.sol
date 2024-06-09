// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Token.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Market {
  Token public yToken;
  Token public nToken;
  address public admin;
  uint256 public totalSupplyY = 0;
  uint256 public totalSupplyN = 0;
  address public oracleAddress;

  struct Bet {
    uint id;
    string description;
    uint256 oddsY;
    uint256 oddsN;
    uint256 stakeY;
    uint256 stakeN;
    uint256 deadline;
    bool resolved;
    bool outcomeY;
  }

  uint256 public nextBetId;
  mapping(uint256 => Bet) public bets;
  mapping(uint256 => mapping(address => uint256)) public stakesY;
  mapping(uint256 => mapping(address => uint256)) public stakesN;
  mapping(address => uint256) public pendingWithdrawals;

  event BetCreated(uint256 indexed betId, string description, uint256 oddsY, uint256 oddsN);
  event TokensPurchased(uint256 indexed betId, address indexed buyer, uint256 amount, bool isYToken);
  event BetResolved(uint256 indexed betId, bool outcomeY);
  event BetFinalized(uint256 indexed betId, uint256 totalStakeY, uint256 totalStakeN);
  event WinningsWithdrawn(address indexed bettor, uint256 amount);

  constructor(address _yTokenAddress, address _nTokenAddress) {
    yToken = Token(_yTokenAddress);
    nToken = Token(_nTokenAddress);
    admin = msg.sender;
  }

  function setOracleAddress(address _oracleAddress) public {
    require(msg.sender == admin, "Only admin can set the oracle address");
    oracleAddress = _oracleAddress;
  }

  function createBet(string memory _description, uint256 _oddsY, uint256 _oddsN, uint256 _duration) {
    uint256 stakeAmount = calculateInitialStake(_oddsY, _oddsN);
    require(msg.value >= stakeAmount, "Deposit must cover the higher odds stake");

    uint256 betId = nextBetId++;
    bets[betId] = Bet({
      id: betId,
      description: _description,
      oddsY: _oddsY,
      oddsN: _oddsN,
      stakeY: _oddsY > _oddsN ? stakeAmount : 0,
      stakeN: _oddsN > _oddsY ? stakeAmount : 0,
      deadline: block.timestamp + _duration,
      resolved: false,
      outcomeY: false
    });

    emit BetCreated(betId, _description, _oddsY, _oddsN, _duration);

    if (_oddsY > _oddsN) {
      yToken.mint(msg.sender, stakeAmount);
      totalSupplyY += stakeAmount;
    } else {
      nToken.mint(msg.sender, stakeAmount);
      totalSupplyN += stakeAmount;
    }
  }

  function calculateInitialStake(uint256 _oddsY, uint256 _oddsN) private pure returns (uint256) {
    return _oddsY > _oddsN ? _oddsY : _oddsN;
  }

  function buyTokens(uint256 _betId, uint256 _amount, bool _buyingY) public {
    Bet storage bet = bets[_betId];
    require(!bet.resolved, "Bet has already been resolved");

    uint256 requiredTokens = _amount;

    if (_buyingY) {
      if (totalSupplyY < requiredTokens) {
        uint256 shortage = requiredTokens - totalSupplyY;
        adjustTokenSupply(shortage, true);
      }
      yToken.mint(msg.sender, requiredTokens);
      totalSupplyY += requiredTokens;
      stakesY[_betId][msg.sender] += requiredTokens;
    } else {
      if (totalSupplyN < requiredTokens) {
        uint256 shortage = requiredTokens - totalSupplyN;
        adjustTokenSupply(shortage, false);
      }
      nToken.mint(msg.sender, requiredTokens);
      totalSupplyN += requiredTokens;
      stakesN[_betId][msg.sender] += requiredTokens;
    }
    emit TokensPurchased(_betId, msg.sender, _amount, _buyingY);
  }

  function adjustTokenSupply(uint256 _amount, bool _adjustingY) private {
    uint256 B = totalSupplyY + totalSupplyN - 2 * _amount;
    uint256 C = -_amount * (_adjustingY ? totalSupplyY : totalSupplyN);
    uint256 m = solveQuadratic(2, B, C);
    yToken.mint(address(this), m);
    nToken.mint(address(this), m);
    if (_adjustingY) {
      totalSupplyY += m;
    } else {
      totalSupplyN += m;
    }
  }

  function solveQuadratic(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
    uint256 delta = b * b - 4 * a * c;
    require(delta >= 0, "No real solutions");
    return(-b + sqrt(delta)) / (2 * a);
  }

  function sqrt(uint256 x) private pure returns (uint256 y) {
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }

    return y;
  }

  function resolveBet(uint256 _betId, bool _outcomeY) public { 
    require(msg.sender == admin || msg.sender == oracleAddress, "Unauthorized");
    Bet storage bet = bets[_betId];
    require(!bet.resolved, "Bet already resolved");
    require(block.timestamp > bet.deadline, "Bet deadline has not passed yet");

    bet.resolved = true;
    bet.outcomeY = _outcomeY;

    emit BetResolved(_betId, _outcomeY);
    emit BetFinalized(_betId, bets[_betId].stakeY, bets[_betId].stakeN);
  }

  function distributeWinnings(uint256 _betId) private {
    Bet storage bet = bets[_betId];
    uint256 rewardPerToken = bet.outcomeY ? (bet.stakeY + bet.stakeN) / bet.stakeY : (bet.stakeY + bet.stakeN) / bet.stakeN;

    if (bet.outcomeY) {
      for (uint256 i = 0; i < bettorsY[_betId].length; i++) {
        address bettor = bettorsY[_betId][i];
        uint256 stake = stakesY[_betId][bettor];
        pendingWithdrawals[bettor] += stake * rewardPerToken;
      }
    } else {
      for (uint256 i = 0; i < bettorsN[_betId].length; i++) {
        address bettor = bettorsN[_betId][i];
        uint256 stake = stakesN[_betId][bettor];
        pendingWithdrawals[bettor] += stake * rewardPerToken;
      }
    }
  }

  function withdrawWinnings() public {
    uint256 amount = pendingWithdrawals[msg.sender];
    require(amount > 0, "No winnings to withdraw");

    pendingWithdrawals[msg.sender] = 0;
    (bool sent, ) = msg.sender.call{value: amount("")};
    require(send, "Failed to send Winnings");
    emit WinningsWithdrawn(msg.sender, amount);
  }
}