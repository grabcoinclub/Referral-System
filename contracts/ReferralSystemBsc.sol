// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./lib/BinaryTreeLib.sol";

contract ReferralSystemBsc is Ownable, Pausable {
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

    address public wallet;

    BinaryTreeLib.Tree private tree;

    event Purchased(address user, uint256 level, uint256 quantity);
    event RefLevelUpgraded(address user, uint256 newLevel, uint256 oldLevel);

    constructor() public {
        //, uint256[][] memory refLevelRate
        //tree.refLevelRate = refLevelRate;
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

        tree.addNodeMyStats(_msgSender(), value);
        tree.payReferral(_msgSender(), value);

        if (wallet != address(0)) {
            //payable(wallet).transfer(balance());
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
        tree.addNodeMyStats(_msgSender(), difference);
        tree.payReferral(_msgSender(), difference);

        if (wallet != address(0)) {
            //payable(wallet).transfer(balance());
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
