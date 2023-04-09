// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library BinaryTreeLib {
    /** @dev The number of seconds in a day. 60*60*24=86400. */
    uint256 public constant DAY = 86_400;
    /** @dev Divisor for calculating percentages. 100/10000=0.01=1%. */
    uint256 public constant DECIMALS = 10_000;
    /** @dev The address of an empty tree node. */
    address public constant EMPTY = address(0);

    /**
     * @dev Distribution of partners in the binary tree.
     * 0 - RANDOM (default);
     * 1 - RIGHT;
     * 2 - LEFT.
     */
    enum Direction {
        RANDOM,
        RIGHT,
        LEFT
    }

    /**
     * @dev Statistics for each day from start.
     */
    struct NodeStats {
        uint256 my;
        uint256 left;
        uint256 right;
        uint256 total;
    }

    /**
     * @dev Received rewards for each day from start.
     */
    struct NodeRewards {
        uint256 ref;
        uint256 bin;
    }

    /**
     * @dev Binary tree node object.
     * @param id - Node id.
     * @param level - Partner level.
     * @param height - Node height from binary tree root.
     * @param parent -  Parent node.
     * @param left - Node on the left.
     * @param right - Node on the right.
     * @param direction - Referral distribution by tree branches.
     * @param partners - List of invited partners.
     * @param stats - Statistics for each day from start.
     * @param rewards - Received rewards for each day from start.
     */
    struct Node {
        uint256 id;
        uint256 level;
        uint256 height;
        address referrer;
        bool isSponsoredRight;
        address parent;
        address left;
        address right;
        Direction direction;
        address[] partners;
        NodeRewards rewardsTotal;
        mapping(uint256 => NodeStats) stats;
        mapping(uint256 => NodeRewards) rewards;
    }

    /**
     * @dev Binary tree.
     * @param root - The Root of the binary tree.
     * @param count - Number of nodes in the binary tree.
     * @param start - Unix timestamp at 00:00.
     * @param upLimit - The maximum number of nodes to update statistics. If 0, then there are no limit.
     * @param refLimit - The maximum number of nodes to pay rewards.
     * @param refLevelRate - List of percentages for each line for each level.
     * @param ids - Table of accounts of the binary tree.
     * @param nodes - Table of nodes of the binary tree.
     */
    struct Tree {
        address root;
        uint256 count;
        uint256 start;
        uint256 upLimit;
        uint256 refLimit;
        uint256[][] refLevelRate;
        mapping(uint256 => address) ids;
        mapping(address => Node) nodes;
        NodeRewards rewardsTotal;
        mapping(uint256 => NodeRewards) rewards;
    }

    // Events
    event Registration(
        address indexed account,
        address indexed referrer,
        address indexed parent,
        uint256 id,
        Direction parentDirection
    );
    event DirectionChange(address indexed account, Direction direction);
    event LevelChange(
        address indexed account,
        uint256 oldLevel,
        uint256 newLevel
    );

    event Purchased(address user, uint256 level, uint256 quantity);
    event RefLevelUpgraded(address user, uint256 newLevel, uint256 oldLevel);

    event PaidReferral(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 line
    );
    event PaidBinar(address indexed to, uint256 day, uint256 amount);
    event Exit(address indexed account, uint256 level);

    /** @dev Current day from start time. */
    function getCurrentDay(Tree storage self) internal view returns (uint256) {
        return (block.timestamp - self.start) / DAY;
    }

    function setUpLimit(Tree storage self, uint256 upLimit) internal {
        self.upLimit = upLimit;
    }

    function lastLeftIn(
        Tree storage self,
        address account
    ) internal view returns (address) {
        while (self.nodes[account].left != EMPTY) {
            account = self.nodes[account].left;
        }
        return account;
    }

    function lastRightIn(
        Tree storage self,
        address account
    ) internal view returns (address) {
        while (self.nodes[account].right != EMPTY) {
            account = self.nodes[account].right;
        }
        return account;
    }

    function exists(
        Tree storage self,
        address account
    ) internal view returns (bool _exists) {
        if (account == EMPTY) return false;
        if (account == self.root) return true;
        if (self.nodes[account].parent != EMPTY) return true;
        return false;
    }

    function getNode(
        Tree storage self,
        address account
    )
        internal
        view
        returns (
            uint256 _id,
            uint256 _level,
            uint256 _height,
            address _referrer,
            address _parent,
            address _left,
            address _right,
            Direction _direction
        )
    {
        Node storage gn = self.nodes[account];
        return (
            gn.id,
            gn.level,
            gn.height,
            gn.referrer,
            gn.parent,
            gn.left,
            gn.right,
            gn.direction
        );
    }

    function getNodeStats(
        Tree storage self,
        address account
    )
        internal
        view
        returns (
            uint256 _partnersTotal,
            uint256 _rewardsRefTotal,
            uint256 _rewardsBinTotal
        )
    {
        Node storage gn = self.nodes[account];
        return (gn.partners.length, gn.rewardsTotal.ref, gn.rewardsTotal.bin);
    }

    function getNodeStatsInDay(
        Tree storage self,
        address account,
        uint256 day
    )
        internal
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
        Node storage gn = self.nodes[account];
        return (
            gn.rewards[day].ref,
            gn.rewards[day].bin,
            gn.stats[day].my,
            gn.stats[day].left,
            gn.stats[day].right,
            gn.stats[day].total
        );
    }

    /**
     * @dev A function that returns the random distribution direction.
     */
    function _randomDirection(
        Tree storage self
    ) private view returns (Direction direction) {
        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    self.count,
                    msg.sender,
                    block.prevrandao,
                    block.timestamp
                )
            )
        ) % uint256(10000);
        if (random < uint256(5000)) return Direction.RIGHT;
        else return Direction.LEFT;
    }

    function insertNode(
        Tree storage self,
        address referrer,
        address account
    ) internal {
        require(!isContract(account), "Cannot be a contract");

        Direction direction = self.nodes[referrer].direction;

        Node storage refNode = self.nodes[referrer];
        if (refNode.partners.length == 0) {
            if (refNode.isSponsoredRight) direction = Direction.RIGHT;
            else direction = Direction.LEFT;
        }
        refNode.partners.push(account);

        if (direction == Direction.RANDOM) {
            direction = _randomDirection(self); // RIGHT or LEFT
        }

        address cursor;
        if (direction == Direction.RIGHT) {
            cursor = lastRightIn(self, referrer);
            self.nodes[cursor].right = account;
        } else if (direction == Direction.LEFT) {
            cursor = lastLeftIn(self, referrer);
            self.nodes[cursor].left = account;
        }

        self.count++;
        self.ids[self.count] = account;

        Node storage newNode = self.nodes[account];
        newNode.id = self.count;
        newNode.level = 0;
        newNode.height = self.nodes[cursor].height + 1;
        newNode.referrer = referrer;
        newNode.isSponsoredRight = refNode.isSponsoredRight; // ? пройтись нужно
        newNode.parent = cursor;
        newNode.left = EMPTY;
        newNode.right = EMPTY;
        newNode.direction = Direction.RANDOM;

        emit Registration(
            account,
            newNode.referrer,
            newNode.parent,
            newNode.id,
            direction
        );
    }

    function setNodeLevel(
        Tree storage self,
        address account,
        uint256 level
    ) internal {
        emit LevelChange(account, self.nodes[account].level, level);
        self.nodes[account].level = level;
    }

    function setNodeDirection(
        Tree storage self,
        address account,
        Direction direction
    ) internal {
        emit DirectionChange(account, direction);
        self.nodes[account].direction = direction;
    }

    function addNodeMyStats(
        Tree storage self,
        address account,
        uint256 value
    ) internal {
        uint256 day = getCurrentDay(self);
        Node storage gn = self.nodes[account];
        gn.stats[day].my += value;
        gn.stats[day].total =
            gn.stats[day].my +
            gn.stats[day].left +
            gn.stats[day].right;

        bool finished;
        uint256 i = 0;
        address cursor = gn.parent;
        address probe = account;
        while (!finished) {
            Node storage un = self.nodes[cursor];
            if (probe == un.right) {
                un.stats[day].right += value;
            } else if (probe == un.left) {
                un.stats[day].left += value;
            }
            un.stats[day].total =
                un.stats[day].my +
                un.stats[day].left +
                un.stats[day].right;

            probe = cursor;
            cursor = un.parent;
            if (cursor == EMPTY) {
                finished = true;
            } else if (self.upLimit > 0) {
                i++;
                if (i >= self.upLimit) {
                    finished = true;
                }
            }
        }
    }

    function addNodeRewardsRef(
        Tree storage self,
        address account,
        uint256 value
    ) internal {
        uint256 day = getCurrentDay(self);
        Node storage gn = self.nodes[account];
        gn.rewardsTotal.ref += value;
        gn.rewards[day].ref += value;
    }

    function addNodeRewardsBin(
        Tree storage self,
        address account,
        uint256 value
    ) internal {
        uint256 day = getCurrentDay(self);
        Node storage gn = self.nodes[account];
        gn.rewardsTotal.bin += value;
        gn.rewards[day].bin += value;
    }

    function addTreeRewardsRef(Tree storage self, uint256 value) internal {
        uint256 day = getCurrentDay(self);
        self.rewardsTotal.ref += value;
        self.rewards[day].ref += value;
    }

    function addTreeRewardsBin(Tree storage self, uint256 value) internal {
        uint256 day = getCurrentDay(self);
        self.rewardsTotal.bin += value;
        self.rewards[day].bin += value;
    }

    /**
     * @dev This will calc and pay referral to uplines instantly
     * @param - value The number tokens will be calculated in referral process
     * @return - the total referral bonus paid
     */
    function payReferral(
        Tree storage self,
        address account,
        uint256 value
    ) internal returns (uint256) {
        uint256 totalPaid;
        address cursor = account;
        for (uint256 i; i < self.refLimit; i++) {
            address payable referrer = payable(self.nodes[cursor].referrer);
            Node storage rn = self.nodes[referrer];
            if (referrer == EMPTY || referrer == self.root) {
                break;
            }

            uint256 c = (value * self.refLevelRate[rn.level][i]) / DECIMALS;
            if (c > 0) {
                totalPaid += c;
                sendValue(referrer, c);
                // node stats
                addNodeRewardsRef(self, referrer, c);
            }
            emit PaidReferral(account, referrer, c, i + 1);

            cursor = referrer;
        }

        // tree stats
        addTreeRewardsRef(self, totalPaid);
        return totalPaid;
    }

    /** @dev Returns the sum of all numbers in an array. */
    function sum(uint256[] memory data) internal pure returns (uint256 s) {
        for (uint256 i; i < data.length; i++) {
            s += data[i];
        }
    }

    /** @dev Returns the minimum number. */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a < b) return a;
        else return b;
    }

    /** @dev Returns true if `account` is a contract. */
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    /** @dev Send value to recipient. */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "INSUFFICIENT_BALANCE");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "TRANSFER_FAILED");
    }
}
