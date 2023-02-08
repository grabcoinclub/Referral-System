// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./lib/ReferralTreeLib.sol";

contract ReferralSystemPolygon is Ownable, Pausable {
    using Address for address;
    using ReferralTreeLib for ReferralTreeLib.Tree;

    // @TODO
    uint256[] public prices = [
        0,
        0.001 ether,
        0.002 ether,
        0.003 ether,
        0.004 ether,
        0.005 ether,
        0.006 ether,
        0.007 ether,
        0.008 ether,
        0.009 ether,
        0.010 ether,
        0.011 ether,
        0.012 ether,
        0.013 ether,
        0.014 ether,
        0.015 ether,
        0.016 ether
    ];
    uint256[] public series = [
        0,
        3000,
        2500,
        2200,
        1800,
        1500,
        1300,
        1100,
        800,
        500,
        300,
        200,
        150,
        100,
        70,
        25,
        10
    ];

    ReferralTreeLib.Tree private tree;

    constructor() public {
        //
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function reduceQuantity(uint256 level, uint256 quantity)
        external
        onlyOwner
    {
        require(series[level] >= quantity, "Incorrect quantity");
        series[level] -= quantity;
    }
}
