// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/ReferralTreeLib.sol";

contract ReferralSystemPolygon is ReentrancyGuard, Ownable, Pausable {
    using ReferralTreeLib for ReferralTreeLib.Tree;

    /** @dev Divisor for calculating percentages. */
    uint256 public constant DECIMALS = ReferralTreeLib.DECIMALS;

    /** @dev The MATIC price of each level is from 1 to 16. */
    uint256[] public prices = [
        0,
        100 ether,
        300 ether,
        500 ether,
        700 ether,
        1_000 ether,
        3_000 ether,
        5_000 ether,
        7_000 ether,
        10_000 ether,
        30_000 ether,
        50_000 ether,
        70_000 ether,
        100_000 ether,
        150_000 ether,
        200_000 ether,
        300_000 ether
    ];

    /** @dev The number of NFTs in each level/series is from 1 to 16. */
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

    ReferralTreeLib.Tree private _tree;

    /**
     * @dev Team wallet.
     * If it is not set, then payments remain at the address of the contract.
     */
    address public wallet;

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
            if (refLevelRate[i].length > _tree.refLimit) {
                _tree.refLimit = refLevelRate[i].length;
            }
        }
        _tree.refLevelRate = refLevelRate;

        // tree
        _tree.start = 0; // TODO
        _tree.root = address(this);
        _tree.count++;
        _tree.ids[_tree.count] = _tree.root;

        ReferralTreeLib.Node storage rootNode = _tree.nodes[_tree.root];
        rootNode.id = _tree.count;

        emit ReferralTreeLib.Registration(
            _tree.root,
            rootNode.referrer,
            rootNode.id
        );
    }

    function join(address referrer) public whenNotPaused {
        if (!_tree.exists(referrer)) {
            referrer = _tree.root;
        }
        if (!_tree.exists(_msgSender())) {
            _tree.insertNode(referrer, _msgSender());
        }
    }

    function upgrade(
        address referrer,
        uint256 nextLevel
    ) external payable whenNotPaused {
        join(referrer);

        uint256 currentLevel = _tree.nodes[_msgSender()].level;
        require(
            nextLevel > currentLevel,
            "The next level must be above the current level"
        );
        require(nextLevel < series.length, "Incorrect next level");
        require(series[nextLevel] > 0, "Next level is over");

        uint256 difference = prices[nextLevel] - prices[currentLevel];
        require(msg.value == difference, "Incorrect value");
        emit ReferralTreeLib.Purchased(_msgSender(), nextLevel, 1);
        emit ReferralTreeLib.RefLevelUpgraded(
            _msgSender(),
            nextLevel,
            currentLevel
        );

        if (currentLevel > 0) {
            series[currentLevel]++;
            _tree.nodes[_msgSender()].balance[currentLevel]--;
        }
        series[nextLevel]--;
        _tree.nodes[_msgSender()].balance[nextLevel]++;
        _tree.setNodeLevel(_msgSender(), nextLevel);
        uint256 refPaid = _tree.payReferral(_msgSender(), difference);

        if (wallet != address(0)) {
            uint256 valueOut = difference - refPaid;
            ReferralTreeLib.sendValue(payable(wallet), valueOut);
        }
    }

    function buy(
        address referrer,
        uint256 level,
        uint256 quantity
    ) external payable whenNotPaused {
        join(referrer);

        uint256 balanceTotal = _tree.getBalanceTotal(_msgSender());
        require(balanceTotal + quantity <= 5, "MAX LIMIT 5");
        require(series[level] >= quantity, "Next level is over");

        uint256 total = prices[level] * quantity;
        require(msg.value == total, "Incorrect value");

        series[level] -= quantity;
        _tree.nodes[_msgSender()].balance[level] += quantity;
        emit ReferralTreeLib.Purchased(_msgSender(), level, quantity);

        uint256 currentLevel = _tree.nodes[_msgSender()].level;
        if (currentLevel < level) {
            _tree.setNodeLevel(_msgSender(), level);
            emit ReferralTreeLib.RefLevelUpgraded(
                _msgSender(),
                level,
                currentLevel
            );
        }
        uint256 refPaid = _tree.payReferral(_msgSender(), total);

        if (wallet != address(0)) {
            uint256 valueOut = total - refPaid;
            ReferralTreeLib.sendValue(payable(wallet), valueOut);
        }
    }

    function exit() external whenNotPaused {
        uint256 currentLevel = _tree.nodes[_msgSender()].level;
        require(currentLevel > 0, "Level 0");

        for (uint256 i = 1; i <= 16; i++) {
            uint256 balanceTotal = _tree.nodes[_msgSender()].balance[i];
            if (balanceTotal > 0) {
                for (uint256 j; j < balanceTotal; j++) {
                    emit ReferralTreeLib.Exit(_msgSender(), i);
                }
                _tree.nodes[_msgSender()].balance[i] = 0;
            }
        }
        _tree.setNodeLevel(_msgSender(), 0);
    }

    /** @dev Changes the contract state: locked, unlocked. */
    function pause(bool status) external onlyOwner {
        if (status) _pause();
        else _unpause();
    }

    /** @dev Reducing the number of NFTs in a series/level. level: 1-16. */
    function reduceLevelQuantity(
        uint256 level,
        uint256 quantity
    ) external onlyOwner {
        require(series[level] >= quantity, "Incorrect quantity");
        series[level] -= quantity;
    }

    /** @dev Setting up a wallet for automatic payments to the Team. */
    function setWallet(address newWallet) external onlyOwner {
        wallet = newWallet;
    }

    /** @dev Returns the contract balance in wei. */
    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    /** @dev Receiving funds from a smart contract account. */
    function withdraw(uint256 value) external onlyOwner nonReentrant {
        ReferralTreeLib.sendValue(payable(_msgSender()), value);
    }

    function getTreeParams()
        external
        view
        returns (address _root, uint256 _count, uint256 _start, uint256 _day)
    {
        _root = _tree.root;
        _count = _tree.count;
        _start = _tree.start;
        _day = _tree.getCurrentDay();
    }

    function getTreeStats() external view returns (uint256 _rewardsRefTotal) {
        _rewardsRefTotal = _tree.rewardsTotal;
    }

    function getTreeStatsInDay(
        uint256 day
    ) external view returns (uint256 _rewardsRef) {
        _rewardsRef = _tree.rewards[day];
    }

    function getIdToAccount(uint256 id) external view returns (address) {
        require(id <= _tree.count, "Index out of bounds");
        return _tree.ids[id];
    }

    function isNodeExists(address account) external view returns (bool) {
        return _tree.exists(account);
    }

    function getNode(
        address account
    )
        external
        view
        returns (
            uint256 _id,
            uint256 _level,
            uint256 _height,
            address _referrer
        )
    {
        (_id, _level, _height, _referrer) = _tree.getNode(account);
    }

    // [lvl_0, lvl_1, ..., lvl_16]
    function getNodeBalances(
        address account
    ) external view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](17);
        for (uint256 i = 1; i <= 16; i++) {
            balances[i] = _tree.nodes[account].balance[i];
        }
        return balances;
    }

    function getNodeBalanceTotal(
        address account
    ) external view returns (uint256) {
        return _tree.getBalanceTotal(account);
    }

    function getNodeStats(
        address account
    ) external view returns (uint256 _partnersTotal, uint256 _rewardsRefTotal) {
        (_partnersTotal, _rewardsRefTotal) = _tree.getNodeStats(account);
    }

    function getNodeStatsInDay(
        address account,
        uint256 day
    ) external view returns (uint256 _rewardsRef) {
        (_rewardsRef) = _tree.getNodeStatsInDay(account, day);
    }

    function getNodePartners(
        address account,
        uint256 index,
        uint256 limit
    ) external view returns (address[] memory _partners) {
        uint256 count = _tree.nodes[account].partners.length;
        require(index < count, "Index out of bounds");
        uint256 size = limit;
        if ((index + limit) > count) {
            size = count - index;
        }
        address[] memory partners = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            partners[i] = _tree.nodes[account].partners[index + i];
        }
        return partners;
    }
}
