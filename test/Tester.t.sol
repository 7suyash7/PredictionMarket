// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Market.sol";
import "../src/Token.sol";
import "../src/Oracle.sol";

contract MarketTest is Test {
    Market market;
    Token yToken;
    Token nToken;
    address admin;

    function setUp() public {
        // Deploy tokens first
        yToken = new Token("YToken", "YT", 18);
        nToken = new Token("NToken", "NT", 18);

        // Deploy the Market contract
        market = new Market(address(yToken), address(nToken));
        admin = address(this);  // In tests, the deployer is often the admin
    }

    // Test to check if the Market is deployed correctly
    function testMarketDeployment() public {
        assertEq(address(market.yToken()), address(yToken), "Y Token not set correctly");
        assertEq(address(market.nToken()), address(nToken), "N Token not set correctly");
        assertEq(market.admin(), admin, "Admin not set correctly");
    }

    // Test initial token supplies are set to 0
    function testInitialTokenSupplies() public {
        assertEq(yToken.totalSupply(), 0, "Initial Y token supply should be 0");
        assertEq(nToken.totalSupply(), 0, "Initial N token supply should be 0");
    }
}