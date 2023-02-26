// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./lib/ReferralTreeLib.sol";

contract ReferralSystemPolygon is Ownable, Pausable {
    using ReferralTreeLib for ReferralTreeLib.Tree;

    uint256 public constant DECIMALS = ReferralTreeLib.DECIMALS;
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
        3_000,
        2_500,
        2_200,
        1_800,
        1_500,
        1_300,
        1_100,
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

    ReferralTreeLib.Tree private tree;

    event Purchased(address user, uint256 level, uint256 quantity);
    event RefLevelUpgraded(address user, uint256 newLevel, uint256 oldLevel);

    constructor(uint256[][] memory refLevelRate) public {
        // ref sistem
        require(
            refLevelRate.length > 0,
            "Referral levels should be at least one"
        );
        for (uint256 i; i < refLevelRate.length; i++) {
            require(
                ReferralTreeLib.sum(refLevelRate[i]) <= DECIMALS,
                "Total level rate exceeds 100%"
            );
            if (refLevelRate[i].length > tree.refLimit) {
                tree.refLimit = refLevelRate[i].length;
            }
        }
        tree.refLevelRate = refLevelRate;

        // tree
        tree.start = 0;
        tree.root = address(this);
        tree.count++;
        tree.ids[tree.count] = tree.root;

        ReferralTreeLib.Node storage rootNode = tree.nodes[tree.root];
        rootNode.id = tree.count;
        rootNode.level = 0;
        rootNode.height = 1;
        rootNode.referrer = ReferralTreeLib.EMPTY;
        rootNode.partners = 0;

        emit ReferralTreeLib.Registration(
            tree.root,
            rootNode.referrer,
            rootNode.id
        );
    }

    function join(address referrer) public whenNotPaused {
        if (!tree.exists(referrer)) {
            referrer = tree.root;
        }
        if (!tree.exists(_msgSender())) {
            tree.insertNode(referrer, _msgSender());
        }
    }

    function upgrade(address referrer, uint256 nextLevel)
        external
        payable
        whenNotPaused
    {
        join(referrer);

        uint256 currentLevel = tree.nodes[_msgSender()].level;
        require(
            nextLevel > currentLevel,
            "The next level must be above the current level"
        );
        require(nextLevel < series.length, "Incorrect next level");
        require(series[nextLevel] > 0, "Next level is over");

        uint256 difference = prices[nextLevel] - prices[currentLevel];
        require(msg.value == difference, "Incorrect value");
        emit RefLevelUpgraded(_msgSender(), nextLevel, currentLevel);

        if (currentLevel > 0) {
            series[currentLevel]++;
            tree.nodes[_msgSender()].balance[currentLevel]--;
        }
        series[nextLevel]--;
        tree.nodes[_msgSender()].balance[nextLevel]++;
        tree.setNodeLevel(_msgSender(), nextLevel);
        uint256 refPaid = tree.payReferral(_msgSender(), difference);

        if (wallet != address(0)) {
            uint256 valueOut = difference - refPaid;
            if (valueOut > 0) payable(wallet).transfer(valueOut);
        }
    }

    function buy(
        address referrer,
        uint256 level,
        uint256 quantity
    ) external payable whenNotPaused {
        join(referrer);

        uint256 balanceTotal = tree.getBalanceTotal(_msgSender());
        require(balanceTotal + quantity <= 5, "MAX LIMIT 5");
        require(series[level] >= quantity, "Next level is over");

        uint256 total = prices[level] * quantity;
        require(msg.value == total, "Incorrect value");

        series[level] -= quantity;
        tree.nodes[_msgSender()].balance[level] += quantity;

        uint256 currentLevel = tree.nodes[_msgSender()].level;
        if (currentLevel < level) {
            tree.setNodeLevel(_msgSender(), level);
            emit RefLevelUpgraded(_msgSender(), level, currentLevel);
        }

        uint256 refPaid = tree.payReferral(_msgSender(), total);
        if (wallet != address(0)) {
            uint256 valueOut = total - refPaid;
            if (valueOut > 0) payable(wallet).transfer(valueOut);
        }
    }

    function exit() external whenNotPaused {
        uint256 currentLevel = tree.nodes[_msgSender()].level;
        require(currentLevel > 0, "Level 0");

        for (uint256 i; i < 16; i++) {
            uint256 balanceTotal = tree.nodes[_msgSender()].balance[i];
            if (balanceTotal > 0) {
                for (uint256 j; j < balanceTotal; j++) {
                    emit ReferralTreeLib.Exit(_msgSender(), i);
                }
                tree.nodes[_msgSender()].balance[i] = 0;
            }
        }
        tree.setNodeLevel(_msgSender(), 0);
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

    function getTreeParams()
        external
        view
        returns (
            address _root,
            uint256 _count,
            uint256 _start,
            uint256 _day
        )
    {
        _root = tree.root;
        _count = tree.count;
        _start = tree.start;
        _day = tree.getCurrentDay();
    }

    function getTreeStats() external view returns (uint256 _rewardsRefTotal) {
        _rewardsRefTotal = tree.rewardsTotal;
    }

    function getTreeStatsInDay(uint256 day)
        external
        view
        returns (uint256 _rewardsRef)
    {
        _rewardsRef = tree.rewards[day];
    }

    function getIdToAccount(uint256 id) external view returns (address) {
        require(id <= tree.count, "Index out of bounds");
        return tree.ids[id];
    }

    function isNodeExists(address account) external view returns (bool) {
        return tree.exists(account);
    }

    function getNode(address account)
        external
        view
        returns (
            uint256 _id,
            uint256 _level,
            uint256 _height,
            address _referrer
        )
    {
        (_id, _level, _height, _referrer) = tree.getNode(account);
    }

    function getNodeStats(address account)
        external
        view
        returns (uint256 _partners, uint256 _rewardsRefTotal)
    {
        (_partners, _rewardsRefTotal) = tree.getNodeStats(account);
    }

    function getNodeStatsInDay(address account, uint256 day)
        external
        view
        returns (uint256 _rewardsRef)
    {
        (_rewardsRef) = tree.getNodeStatsInDay(account, day);
    }
}
