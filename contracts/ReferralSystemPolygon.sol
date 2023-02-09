// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./lib/ReferralTreeLib.sol";
import "./lib/BinaryTreeLib.sol";

contract ReferralSystemPolygon is Ownable, Pausable {
    using BinaryTreeLib for BinaryTreeLib.Tree;

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

    address public wallet;

    BinaryTreeLib.Tree private tree;

    event Purchased(address user, uint256 level, uint256 quantity);
    event RefLevelUpgraded(address user, uint256 newLevel, uint256 oldLevel);

    constructor() public {
        //, uint256[][] memory refLevelRate
    }

    function join(address referrer) public whenNotPaused {
        if (!tree.exists(referrer)) {
            referrer = tree.root;
        }
        if (!tree.exists(_msgSender())) {
            tree.insertNode(referrer, _msgSender());
        }
    }

    function buy(
        address referrer,
        uint256 level,
        uint256 quantity
    ) external payable {
        join(referrer);

        require(level > 0, "Incorrect series");
        require(quantity > 0, "Incorrect quantity");
        require(series[level] >= quantity, "This series is over");

        uint256 value = prices[level] * quantity;
        require(msg.value == value, "Incorrect value");
        series[level] -= quantity;
        emit Purchased(_msgSender(), level, quantity);

        uint256 currentLevel = tree.nodes[_msgSender()].level;
        if (level > currentLevel) {
            tree.setNodeLevel(_msgSender(), level);
        }

        tree.payReferral(_msgSender(), value);

        if (wallet != address(0)) {
            payable(wallet).transfer(balance());
        }
    }

    function upgrade(uint256 nextLevel) external payable whenNotPaused {
        uint256 currentLevel = tree.nodes[_msgSender()].level;
        require(
            currentLevel > 0,
            "To update, the current level must be above 0"
        );
        require(
            nextLevel > currentLevel,
            "The next level must be above the current level"
        );
        require(nextLevel < series.length, "Incorrect next level");
        require(series[nextLevel] > 0, "Next level is over");

        uint256 difference = prices[nextLevel] - prices[currentLevel];
        require(msg.value == difference, "Incorrect value");
        emit RefLevelUpgraded(_msgSender(), nextLevel, currentLevel);

        series[currentLevel]++;
        series[nextLevel]--;
        tree.setNodeLevel(_msgSender(), nextLevel);
        tree.payReferral(_msgSender(), difference);

        if (wallet != address(0)) {
            payable(wallet).transfer(balance());
        }
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

    function setWallet(address newWallet) external onlyOwner {
        wallet = newWallet;
    }

    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdraw(uint256 value) external onlyOwner {
        require(value <= balance(), "Incorrect value");
        payable(_msgSender()).transfer(value);
    }
}
