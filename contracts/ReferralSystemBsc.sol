// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./lib/BinaryTreeLib.sol";

contract ReferralSystemBsc is EIP712, ReentrancyGuard, Ownable, Pausable {
    using Counters for Counters.Counter;
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
    mapping(address => Counters.Counter) private _nonces;
    bytes32 private constant _WITHDRAW_TYPEHASH =
        keccak256("claimBinaryRewardsOffChain(address user,uint256 amount,uint256 day,uint256 nonce)");

    event SignerChanged(address indexed oldSigner, address indexed newSigner);

    constructor(uint256[][] memory refLevelRate) EIP712("Referral System", "1") {

        // ref system
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
        _tree.start = 1680998400; // 2023-04-09T00:00:00.000Z = 1680998400
        _tree.upLimit = 0; // 0 - unlimited

        wallet = 0xdf945BCC25D0f8eD32272341a34E93781eEbfe97;

        // binary system
        isBinaryOnChain = true;
    }

    function joinByAdmin(address referrer, address referee) public onlyOwner {
        _join(referrer, referee);
    }

    function join(address referrer) public {
        _join(referrer, _msgSender());
    }

    function _join(address referrer, address referee) internal whenNotPaused {
        if (!_tree.exists(referrer)) {
            referrer = _tree.root;
        }
        if (!_tree.exists(referee)) {
            _tree.insertNode(referrer, referee);
        }
    }

    function upgradeByAdmin(address user, uint256 nextLevel) external onlyOwner {
        _upgrade(user, nextLevel);
    }

    function upgrade(uint256 nextLevel) external payable {
        uint256 currentLevel = _tree.nodes[_msgSender()].level;
        uint256 difference = prices[nextLevel] - prices[currentLevel];
        require(msg.value == difference, "Incorrect value");

        _upgrade(_msgSender(), nextLevel);
    }

    function _upgrade(address user, uint256 nextLevel) internal whenNotPaused nonReentrant {
        require(_tree.exists(user), "Node does not exist");

        uint256 currentLevel = _tree.nodes[user].level;
        uint256 difference = prices[nextLevel] - prices[currentLevel];
        require(
            nextLevel > currentLevel,
            "The next level must be above the current level"
        );
        require(nextLevel < series.length, "Incorrect next level");
        require(series[nextLevel] > 0, "Next level is over");

        emit BinaryTreeLib.Purchased(user, nextLevel, 1);
        emit BinaryTreeLib.RefLevelUpgraded(user, nextLevel, currentLevel);

        if (currentLevel > 0) series[currentLevel]++;
        series[nextLevel]--;
        _tree.setNodeLevel(user, nextLevel);
        if (isBinaryOnChain) {
            _tree.addNodeMyStats(user, difference);
        }
        uint256 refPaid = _tree.payReferral(user, difference);

        if (wallet != address(0)) {
            uint256 valueOut = (difference * 6000) / DECIMALS; // 6000/10000=60%
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
        bytes memory signature
    ) external whenNotPaused nonReentrant {
        require(!isBinaryOnChain, "Not activated");

        bytes32 structHash = keccak256(
            abi.encode(_WITHDRAW_TYPEHASH, msg.sender, amount, day, _useNonce(msg.sender))
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        require(ECDSA.recover(hash, signature) == signer, "Invalid signer");

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

    /** @dev Returns the nonce for the owner. */
    function nonces(address owner) public view returns (uint256) {
        return _nonces[owner].current();
    }

    /** @dev "Consume a nonce": return the current value and increment. */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
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
