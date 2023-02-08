// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./lib/BinaryTreeLib.sol";

contract ReferralSystemBsc is Ownable, Pausable {
    using Address for address;
    using BinaryTreeLib for BinaryTreeLib.Tree;

    uint256[] public prices = [
        0,
        0.2 ether,
        0.3 ether,
        0.5 ether,
        1 ether,
        2 ether,
        3 ether,
        5 ether,
        10 ether,
        18 ether,
        30 ether,
        50 ether,
        100 ether,
        180 ether,
        300 ether,
        500 ether
    ];
    uint256[] public series = [
        0,
        3000,
        2800,
        2300,
        2000,
        1700,
        1500,
        1000,
        550,
        300,
        200,
        100,
        50,
        25,
        20,
        10
    ];

    BinaryTreeLib.Tree private tree;

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
