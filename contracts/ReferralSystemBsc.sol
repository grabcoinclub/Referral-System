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

        // binary sistem
        isBinaryOnChain = true;

        _tree.start = 0; // TODO
        _tree.upLimit = 0; // 0 - unlimit
        _tree.root = address(this);
        _tree.count++;
        _tree.ids[_tree.count] = _tree.root;

        BinaryTreeLib.Node storage rootNode = _tree.nodes[_tree.root];
        rootNode.id = _tree.count;
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
            _tree.root,
            rootNode.referrer,
            rootNode.parent,
            rootNode.id,
            BinaryTreeLib.Direction.RIGHT
        );
        emit BinaryTreeLib.DirectionChange(
            _tree.root,
            BinaryTreeLib.Direction.RIGHT
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
            if ((difference - refPaid) < valueOut)
                valueOut = difference - refPaid;
            BinaryTreeLib.sendValue(payable(wallet), valueOut);
        }
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
        uint256 paid = amount - _tree.nodes[_msgSender()].rewards[day].bin;
        BinaryTreeLib.sendValue(payable(_msgSender()), paid);
        emit BinaryTreeLib.PaidBinar(_msgSender(), day, paid);

        // node stats
        _tree.addNodeRewardsBin(_msgSender(), paid);
        // tree stats
        _tree.addTreeRewardsBin(paid);
    }

    /** @dev Receiving binary rewards when switching to off-chain counting. */
    function claimBinaryRewardsOffChain(
        address user,
        uint256 amount,
        uint256 day,
        uint256 signId,
        bytes memory signature
    ) external whenNotPaused nonReentrant {
        _checkSignature(user, amount, day, signId, signature);
        emit BinaryTreeLib.PaidBinar(user, day, amount);

        // node stats
        _tree.addNodeRewardsBin(user, amount);
        // tree stats
        _tree.addTreeRewardsBin(amount);
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
    function withdraw(uint256 value) external onlyOwner {
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
            uint256 _partners,
            uint256 _rewardsRefTotal,
            uint256 _rewardsBinTotal
        )
    {
        (_partners, _rewardsRefTotal, _rewardsBinTotal) = _tree.getNodeStats(
            account
        );
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
}
