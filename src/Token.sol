// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
  address public admin;

  constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    admin = msg.sender;
  }

  function mint(address to, uint256 amount) external {
    require(msg.sender == admin, "Only admin can mint tokens");
    _mint(to, amount);
  }

  function burn(uint256 amount) external {
    _burn(msg.sender, amount);
  }
}