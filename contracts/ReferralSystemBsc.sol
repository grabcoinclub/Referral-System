// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./lib/BinaryTreeLib.sol";

contract ReferralSystemBsc is Ownable, Pausable {
    using BinaryTreeLib for BinaryTreeLib.Tree;

    uint256 public constant DECIMALS = 10000;
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
    uint256[] public binLevelRate = [
        0,
        600,
        600,
        700,
        700,
        700,
        800,
        800,
        900,
        900,
        1000,
        1000,
        1100,
        1100,
        1200,
        1200
    ];

    address public wallet;

    BinaryTreeLib.Tree private tree;

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
                BinaryTreeLib.sum(refLevelRate[i]) <= DECIMALS,
                "Total level rate exceeds 100%"
            );
            if (refLevelRate[i].length > tree.refLimit) {
                tree.refLimit = refLevelRate[i].length;
            }
        }
        tree.refLevelRate = refLevelRate;

        // binary sistem
        tree.start = 0;
        tree.upLimit = 0; // 0 - unlimit
        tree.root = address(this);
        tree.count++;
        tree.ids[tree.count] = tree.root;

        BinaryTreeLib.Node storage rootNode = tree.nodes[tree.root];
        rootNode.id = tree.count;
        rootNode.level = 0;
        rootNode.height = 1;
        rootNode.referrer = BinaryTreeLib.EMPTY;
        rootNode.isSponsoredRight = true;
        rootNode.parent = BinaryTreeLib.EMPTY;
        rootNode.left = BinaryTreeLib.EMPTY;
        rootNode.right = BinaryTreeLib.EMPTY;
        rootNode.direction = BinaryTreeLib.Direction.RIGHT;
        rootNode.partners = 0;

        emit BinaryTreeLib.Registration(
            tree.root,
            rootNode.referrer,
            rootNode.parent,
            rootNode.id,
            BinaryTreeLib.Direction.RIGHT
        );
        emit BinaryTreeLib.DirectionChange(
            tree.root,
            BinaryTreeLib.Direction.RIGHT
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

        if (currentLevel > 0) series[currentLevel]++;
        series[nextLevel]--;
        tree.setNodeLevel(_msgSender(), nextLevel);
        tree.addNodeMyStats(_msgSender(), difference);
        uint256 refPaid = tree.payReferral(_msgSender(), difference);

        if (wallet != address(0)) {
            // 6000/10000=60%
            uint256 valueOut = (difference * 6000) / DECIMALS;
            if ((difference - refPaid) < valueOut)
                valueOut = difference - refPaid;
            payable(wallet).transfer(valueOut);
        }
    }

    function claimBinaryRewards(uint256 day) external whenNotPaused {
        BinaryTreeLib.Node storage gn = tree.nodes[_msgSender()];

        gn.stats[day].left;
        gn.stats[day].right;
        uint256 value = BinaryTreeLib.min(
            gn.stats[day].left,
            gn.stats[day].right
        );
        uint256 rate = binLevelRate[gn.level];
        value = (value * rate) / DECIMALS;
        uint256 paid = value - tree.nodes[_msgSender()].rewards[day].bin;
        payable(_msgSender()).transfer(paid);
        emit BinaryTreeLib.PaidBinar(_msgSender(), paid);

        // node stats
        tree.addNodeRewardsBin(_msgSender(), paid);
        // tree stats
        tree.addTreeRewardsBin(paid);
    }

    function exit() external whenNotPaused {
        uint256 currentLevel = tree.nodes[_msgSender()].level;
        require(currentLevel > 0, "Level 0");
        emit BinaryTreeLib.Exit(_msgSender(), currentLevel);
        tree.setNodeLevel(_msgSender(), 0);
    }

    function setTreeNodeDirection(BinaryTreeLib.Direction direction) external {
        require(tree.exists(_msgSender()), "Node does not exist");
        tree.setNodeDirection(_msgSender(), direction);
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
            uint256 _upLimit,
            uint256 _day
        )
    {
        _root = tree.root;
        _count = tree.count;
        _start = tree.start;
        _upLimit = tree.upLimit;
        _day = tree.getCurrentDay();
    }

    function setUpLimit(uint256 upLimit) external onlyOwner {
        tree.setUpLimit(upLimit);
    }

    function getTreeIdToAccount(uint256 id) external view returns (address) {
        require(id <= tree.count, "Index out of bounds");
        return tree.ids[id];
    }

    function treeLastLeftIn(address account) external view returns (address) {
        return tree.lastLeftIn(account);
    }

    function treeLastRightIn(address account) external view returns (address) {
        return tree.lastRightIn(account);
    }

    function treeNodeExists(address account) external view returns (bool) {
        return tree.exists(account);
    }

    function getNode(address account)
        external
        view
        returns (
            uint256 _id,
            uint256 _level,
            uint256 _height,
            address _referrer,
            address _parent,
            address _left,
            address _right,
            BinaryTreeLib.Direction _direction
        )
    {
        (
            _id,
            _level,
            _height,
            _referrer,
            _parent,
            _left,
            _right,
            _direction
        ) = tree.getNode(account);
    }

    function getNodeStats(address account)
        external
        view
        returns (
            uint256 _partners,
            uint256 _rewardsRefTotal,
            uint256 _rewardsBinTotal
        )
    {
        (_partners, _rewardsRefTotal, _rewardsBinTotal) = tree.getNodeStats(
            account
        );
    }

    function getNodeStatsInDay(address account, uint256 day)
        external
        view
        returns (
            uint256 _rewardsRef,
            uint256 _rewardsBin,
            uint256 _statsMy,
            uint256 _statsLeft,
            uint256 _statsRight,
            uint256 _statsTotal
        )
    {
        (
            _rewardsRef,
            _rewardsBin,
            _statsMy,
            _statsLeft,
            _statsRight,
            _statsTotal
        ) = tree.getNodeStatsInDay(account, day);
    }
}
