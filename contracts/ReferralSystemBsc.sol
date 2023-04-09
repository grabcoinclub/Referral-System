// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./lib/BinaryTreeLib.sol";

contract ReferralSystemBsc is ReentrancyGuard, Ownable, Pausable {
    using BinaryTreeLib for BinaryTreeLib.Tree;

    /** @dev Divisor for calculating percentages. */
    uint256 public constant DECIMALS = BinaryTreeLib.DECIMALS;

    /** @dev The BNB price of each level/series is from 1 to 15. */
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

    /** @dev The number of NFTs in each level/series is from 1 to 15. */
    uint256[] public series = [
        0,
        3_000,
        2_800,
        2_300,
        2_000,
        1_700,
        1_500,
        1_000,
        550,
        300,
        200,
        100,
        50,
        25,
        20,
        10
    ];

    /**
     * @dev The percentage of rewards on the binary tree in each level/series is from 1 to 15.
     * 600/10000=0.06=6%.
     */
    uint256[] public binLevelRate = [
        0,
        600,
        600,
        700,
        700,
        800,
        800,
        900,
        900,
        1_000,
        1_000,
        1_100,
        1_100,
        1_200,
        1_200,
        1_200
    ];

    BinaryTreeLib.Tree private _tree;

    /**
     * @dev Team wallet.
     * If it is not set, then payments remain at the address of the contract.
     */
    address public wallet;

    /** @dev Process a binary tree on-chain or off-chain. */
    bool public isBinaryOnChain;
    /** @dev The address signing the payment permission. */
    address public signer;
    uint256 public immutable chainId;
    mapping(address => uint256) public signIds;

    event SignerChanged(address indexed oldSigner, address indexed newSigner);

    constructor(uint256[][] memory refLevelRate) public {
        chainId = block.chainid;

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
            if (refLevelRate[i].length > _tree.refLimit) {
                _tree.refLimit = refLevelRate[i].length;
            }
        }
        _tree.refLevelRate = refLevelRate;

        // tree
        _tree.start = 1680998400; // TODO // 2023-04-09T00:00:00.000Z = 1680998400
        _tree.upLimit = 0; // TODO 0 - unlimit

        /*_tree.root = address(this);
        _tree.count++;
        _tree.ids[_tree.count] = _tree.root;

        BinaryTreeLib.Node storage rootNode = _tree.nodes[_tree.root];
        rootNode.id = _tree.count;
        rootNode.height = 1;
        rootNode.isSponsoredRight = true;
        rootNode.direction = BinaryTreeLib.Direction.RIGHT;

        emit BinaryTreeLib.Registration(
            _tree.root,
            rootNode.referrer,
            rootNode.parent,
            rootNode.id,
            rootNode.direction
        );
        emit BinaryTreeLib.DirectionChange(_tree.root, rootNode.direction);*/

        _setup(
            [
                0x4A91dfbb24a42b4Dc305996c6776aD8b7934Be00,
                0xd317cF9661748F7bB357B378B2F69afeFCd85Ff9,
                0xe461E4bbAE1a791F5DD0C1dDa9905847D44473B6,
                0x4958196c33ECfc18a6dD8Ff583061418d9D50ae6,
                0x969363Ca666c018838AE8Aa7B3C6a9cEAfbf3bA9,
                0xA71C72399D257bFf5513B91b6F5928BA6ef76Aac,
                0xE508464C78d5085dc2A750B04C770Dc273928dE5
            ]
        );

        wallet = 0xdf945BCC25D0f8eD32272341a34E93781eEbfe97;

        // binary sistem
        isBinaryOnChain = true;
    }

    function _setup(address[7] memory users) private {
        _tree.ids[1] = users[0];
        _tree.ids[2] = users[1];
        _tree.ids[3] = users[2];
        _tree.ids[4] = users[3];
        _tree.ids[5] = users[4];
        _tree.ids[6] = users[5];
        _tree.ids[7] = users[6];

        _tree.count = 7;
        _tree.root = _tree.ids[1];

        series[12] -= 1;
        series[10] -= 2;
        series[8] -= 4;

        BinaryTreeLib.Node storage a1 = _tree.nodes[_tree.ids[1]];
        a1.id = 1;
        a1.height = 1;
        a1.level = 12;
        a1.referrer = BinaryTreeLib.EMPTY;
        a1.parent = BinaryTreeLib.EMPTY;
        a1.left = _tree.ids[2];
        a1.right = _tree.ids[3];
        a1.direction = BinaryTreeLib.Direction.RIGHT;
        a1.isSponsoredRight = true;
        a1.partners.push(_tree.ids[2]);
        a1.partners.push(_tree.ids[3]);
        emit BinaryTreeLib.Registration(
            _tree.ids[1],
            a1.referrer,
            a1.parent,
            a1.id,
            a1.direction
        );
        emit BinaryTreeLib.DirectionChange(_tree.ids[1], a1.direction);

        BinaryTreeLib.Node storage a2 = _tree.nodes[_tree.ids[2]];
        a2.id = 2;
        a2.height = 2;
        a2.level = 10;
        a2.referrer = _tree.ids[1];
        a2.parent = _tree.ids[1];
        a2.left = _tree.ids[4];
        a2.right = _tree.ids[5];
        a2.direction = BinaryTreeLib.Direction.LEFT;
        a2.isSponsoredRight = false;
        a2.partners.push(_tree.ids[4]);
        a2.partners.push(_tree.ids[5]);
        emit BinaryTreeLib.Registration(
            _tree.ids[2],
            a2.referrer,
            a2.parent,
            a2.id,
            a2.direction
        );
        emit BinaryTreeLib.DirectionChange(_tree.ids[2], a2.direction);

        BinaryTreeLib.Node storage a3 = _tree.nodes[_tree.ids[3]];
        a3.id = 3;
        a3.height = 2;
        a3.level = 10;
        a3.referrer = _tree.ids[1];
        a3.parent = _tree.ids[1];
        a3.left = _tree.ids[6];
        a3.right = _tree.ids[7];
        a3.direction = BinaryTreeLib.Direction.RIGHT;
        a3.isSponsoredRight = true;
        a3.partners.push(_tree.ids[6]);
        a3.partners.push(_tree.ids[7]);
        emit BinaryTreeLib.Registration(
            _tree.ids[3],
            a3.referrer,
            a3.parent,
            a3.id,
            a3.direction
        );
        emit BinaryTreeLib.DirectionChange(_tree.ids[3], a3.direction);

        BinaryTreeLib.Node storage a4 = _tree.nodes[_tree.ids[4]];
        a4.id = 4;
        a4.height = 3;
        a4.level = 8;
        a4.referrer = _tree.ids[2];
        a4.parent = _tree.ids[2];
        a4.direction = BinaryTreeLib.Direction.LEFT;
        a4.isSponsoredRight = false;
        emit BinaryTreeLib.Registration(
            _tree.ids[4],
            a4.referrer,
            a4.parent,
            a4.id,
            a4.direction
        );
        emit BinaryTreeLib.DirectionChange(_tree.ids[4], a4.direction);

        BinaryTreeLib.Node storage a5 = _tree.nodes[_tree.ids[5]];
        a5.id = 5;
        a5.height = 3;
        a5.level = 8;
        a5.referrer = _tree.ids[2];
        a5.parent = _tree.ids[2];
        a5.direction = BinaryTreeLib.Direction.RIGHT;
        a5.isSponsoredRight = true;
        emit BinaryTreeLib.Registration(
            _tree.ids[5],
            a5.referrer,
            a5.parent,
            a5.id,
            a5.direction
        );
        emit BinaryTreeLib.DirectionChange(_tree.ids[5], a5.direction);

        BinaryTreeLib.Node storage a6 = _tree.nodes[_tree.ids[6]];
        a6.id = 6;
        a6.height = 3;
        a6.level = 8;
        a6.referrer = _tree.ids[3];
        a6.parent = _tree.ids[3];
        a6.direction = BinaryTreeLib.Direction.LEFT;
        a6.isSponsoredRight = false;
        emit BinaryTreeLib.Registration(
            _tree.ids[6],
            a6.referrer,
            a6.parent,
            a6.id,
            a6.direction
        );
        emit BinaryTreeLib.DirectionChange(_tree.ids[6], a6.direction);

        BinaryTreeLib.Node storage a7 = _tree.nodes[_tree.ids[7]];
        a7.id = 7;
        a7.height = 3;
        a7.level = 8;
        a7.referrer = _tree.ids[3];
        a7.parent = _tree.ids[3];
        a7.direction = BinaryTreeLib.Direction.RIGHT;
        a7.isSponsoredRight = true;
        emit BinaryTreeLib.Registration(
            _tree.ids[7],
            a7.referrer,
            a7.parent,
            a7.id,
            a7.direction
        );
        emit BinaryTreeLib.DirectionChange(_tree.ids[7], a7.direction);
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
    ) external payable whenNotPaused nonReentrant {
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

        emit BinaryTreeLib.Purchased(_msgSender(), nextLevel, 1);
        emit BinaryTreeLib.RefLevelUpgraded(
            _msgSender(),
            nextLevel,
            currentLevel
        );

        if (currentLevel > 0) series[currentLevel]++;
        series[nextLevel]--;
        _tree.setNodeLevel(_msgSender(), nextLevel);
        if (isBinaryOnChain) {
            _tree.addNodeMyStats(_msgSender(), difference);
        }
        uint256 refPaid = _tree.payReferral(_msgSender(), difference);

        if (wallet != address(0)) {
            // TODO 6000/10000=60%
            uint256 valueOut = (difference * 6000) / DECIMALS;
            if (valueOut > (difference - refPaid))
                valueOut = difference - refPaid;
            BinaryTreeLib.sendValue(payable(wallet), valueOut);
        }
    }

    function accumulatedBinaryRewards(
        address user,
        uint256 day
    ) public view returns (uint256) {
        BinaryTreeLib.Node storage gn = _tree.nodes[user];

        uint256 amount = BinaryTreeLib.min(
            gn.stats[day].left,
            gn.stats[day].right
        );
        uint256 rate = binLevelRate[gn.level];
        amount = (amount * rate) / DECIMALS;
        uint256 maxDailyLimit = prices[gn.level];
        if (amount > maxDailyLimit) {
            amount = maxDailyLimit;
        }
        return amount;
    }

    function availableBinaryRewards(
        address user,
        uint256 day
    ) public view returns (uint256) {
        BinaryTreeLib.Node storage gn = _tree.nodes[user];
        uint256 amount = accumulatedBinaryRewards(user, day);
        uint256 paid = amount - gn.rewards[day].bin;
        return paid;
    }

    function claimBinaryRewards(
        uint256 day
    ) external whenNotPaused nonReentrant {
        BinaryTreeLib.Node storage gn = _tree.nodes[_msgSender()];

        uint256 amount = BinaryTreeLib.min(
            gn.stats[day].left,
            gn.stats[day].right
        );
        uint256 rate = binLevelRate[gn.level];
        amount = (amount * rate) / DECIMALS;
        uint256 maxDailyLimit = prices[gn.level];
        if (amount > maxDailyLimit) {
            amount = maxDailyLimit;
        }
        uint256 paid = amount - gn.rewards[day].bin;
        BinaryTreeLib.sendValue(payable(_msgSender()), paid);
        emit BinaryTreeLib.PaidBinar(_msgSender(), day, paid);

        // node stats
        _tree.addNodeRewardsBin(_msgSender(), paid, day);
        // tree stats
        _tree.addTreeRewardsBin(paid, day);
    }

    /** @dev Receiving binary rewards when switching to off-chain counting. */
    function claimBinaryRewardsOffChain(
        address user,
        uint256 amount,
        uint256 day,
        uint256 signId,
        bytes memory signature
    ) external whenNotPaused nonReentrant {
        require(!isBinaryOnChain, "Not activated");
        _checkSignature(user, amount, day, signId, signature);

        BinaryTreeLib.Node storage gn = _tree.nodes[user];
        uint256 maxDailyLimit = prices[gn.level];
        if (amount > maxDailyLimit) {
            amount = maxDailyLimit;
        }
        uint256 paid = amount - gn.rewards[day].bin;
        BinaryTreeLib.sendValue(payable(user), paid);
        emit BinaryTreeLib.PaidBinar(user, day, paid);

        // node stats
        _tree.addNodeRewardsBin(user, paid, day);
        // tree stats
        _tree.addTreeRewardsBin(paid, day);
    }

    function exit() external whenNotPaused {
        uint256 currentLevel = _tree.nodes[_msgSender()].level;
        require(currentLevel > 0, "Level 0");
        emit BinaryTreeLib.Exit(_msgSender(), currentLevel);
        _tree.setNodeLevel(_msgSender(), 0);
    }

    /**
     * @dev Sets the distribution of partners in the binary tree.
     * 0 - RANDOM (default);
     * 1 - RIGHT;
     * 2 - LEFT.
     */
    function setTreeNodeDirection(BinaryTreeLib.Direction direction) external {
        require(_tree.exists(_msgSender()), "Node does not exist");
        _tree.setNodeDirection(_msgSender(), direction);
    }

    /** @dev Changes the contract state: locked, unlocked. */
    function pause(bool status) external onlyOwner {
        if (status) _pause();
        else _unpause();
    }

    /** @dev Reducing the number of NFTs in a series/level. level: 1-15. */
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

    /** @dev Setting to process a binary tree on-chain or off-chain. */
    function setBinaryOnChain(bool status) external onlyOwner {
        isBinaryOnChain = status;
    }

    /**
     * @dev Setting upLimit number for on-chain process.
     * The maximum number of nodes to update statistics. If 0, then there are no limit.
     */
    function setUpLimit(uint256 upLimit) external onlyOwner {
        _tree.setUpLimit(upLimit);
    }

    /** @dev Sets the address of the permission signer. */
    function setSigner(address newSigner) external onlyOwner {
        emit SignerChanged(signer, newSigner);
        signer = newSigner;
    }

    function _checkSignature(
        address user,
        uint256 amount,
        uint256 day,
        uint256 signId,
        bytes memory signature
    ) internal {
        require(
            signIds[user] < signId &&
                _signatureWallet(user, amount, day, signId, signature) ==
                signer,
            "Not authorized"
        );
        signIds[user] = signId;
    }

    function _signatureWallet(
        address user,
        uint256 amount,
        uint256 day,
        uint256 signId,
        bytes memory signature
    ) private view returns (address) {
        return
            ECDSA.recover(
                keccak256(abi.encode(chainId, signId, user, amount, day)),
                signature
            );
    }

    /** @dev Returns the contract balance in wei. */
    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    /** @dev Receiving funds from a smart contract account. */
    function withdraw(uint256 value) external onlyOwner nonReentrant {
        BinaryTreeLib.sendValue(payable(_msgSender()), value);
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
        _root = _tree.root;
        _count = _tree.count;
        _start = _tree.start;
        _upLimit = _tree.upLimit;
        _day = _tree.getCurrentDay();
    }

    function getTreeStats()
        external
        view
        returns (uint256 _rewardsRefTotal, uint256 _rewardsBinTotal)
    {
        _rewardsRefTotal = _tree.rewardsTotal.ref;
        _rewardsBinTotal = _tree.rewardsTotal.bin;
    }

    function getTreeStatsInDay(
        uint256 day
    ) external view returns (uint256 _rewardsRef, uint256 _rewardsBin) {
        _rewardsRef = _tree.rewards[day].ref;
        _rewardsBin = _tree.rewards[day].bin;
    }

    function getIdToAccount(uint256 id) external view returns (address) {
        require(id <= _tree.count, "Index out of bounds");
        return _tree.ids[id];
    }

    function getLastNodeLeftIn(
        address account
    ) external view returns (address) {
        return _tree.lastLeftIn(account);
    }

    function getLastNodeRightIn(
        address account
    ) external view returns (address) {
        return _tree.lastRightIn(account);
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
        ) = _tree.getNode(account);
    }

    function getNodeStats(
        address account
    )
        external
        view
        returns (
            uint256 _partnersTotal,
            uint256 _rewardsRefTotal,
            uint256 _rewardsBinTotal
        )
    {
        (_partnersTotal, _rewardsRefTotal, _rewardsBinTotal) = _tree
            .getNodeStats(account);
    }

    function getNodeStatsInDay(
        address account,
        uint256 day
    )
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
        ) = _tree.getNodeStatsInDay(account, day);
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
