// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Market.sol";

contract Oracle {
  address public admin;
  Market public marketContract;

  event OutcomeUpdated(uint256 betId, bool outcomeY, address indexed updater);
  event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

  constructor(address _marketContract) {
    admin = msg.sender;
    marketContract = Market(_marketContract);
  }

  function updateOutcome(uint256 _betId, bool _outcomeY) external {
    require(msg.sender == admin, "Only admin can update outcomes");
    marketContract.resolveBet(_betId, _outcomeY);
    emit OutcomeUpdated(_betId, outcomeY, msg.sender);
  }

  function setAdmin(address _newAdmin) external {
    require(msg.sender == admin, "Unauthorized");
    emit AdminChanged(admin, _newAdminnewAdmin);
    admin = _newAdmin;
  }
}