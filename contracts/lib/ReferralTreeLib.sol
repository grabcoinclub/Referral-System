// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library ReferralTreeLib {
    uint256 public constant DAY = 86_400;
    uint256 public constant DECIMALS = 10_000;
    address public constant EMPTY = address(0);

    /**
     * @dev Binary tree node object.
     * @param id - Node id.
     * @param level - Partner level.
     * @param height - Node height from binary tree root.
     * @param partners - Number of invited partners.
     * @param rewards - Received rewards for each day from start.
     * @param balance - How many nft of each level.
     */
    struct Node {
        uint256 id;
        uint256 level;
        uint256 height;
        address referrer;
        uint256 partners;
        uint256 rewardsTotal;
        mapping(uint256 => uint256) rewards;
        mapping(uint256 => uint256) balance;
    }

    /**
     * @dev Binary tree.
     * @param root - The Root of the tree.
     * @param count - Number of nodes in the tree.
     * @param start - Unix timestamp at 00:00.
     * @param refLimit - The maximum number of nodes to pay rewards.
     * @param refLevelRate - List of percentages for each line for each level.
     * @param ids - Table of accounts of the tree.
     * @param nodes - Table of nodes of the tree.
     */
    struct Tree {
        address root;
        uint256 count;
        uint256 start;
        uint256 refLimit;
        uint256[][] refLevelRate;
        mapping(uint256 => address) ids;
        mapping(address => Node) nodes;
        uint256 rewardsTotal;
        mapping(uint256 => uint256) rewards;
    }

    // Events
    event Registration(
        address indexed account,
        address indexed referrer,
        uint256 id
    );
    event LevelChange(
        address indexed account,
        uint256 oldLevel,
        uint256 newLevel
    );

    event PaidReferral(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 line
    );
    event Exit(address indexed account, uint256 level);

    function getBalance(Tree storage self, address account)
        internal
        view
        returns (uint256 balance)
    {
        for (uint256 i; i < 16; i++) {
            balance += self.nodes[account].balance[i];
        }
    }

    function getCurrentDay(Tree storage self) internal view returns (uint256) {
        return (block.timestamp - self.start) / DAY;
    }

    function exists(Tree storage self, address account)
        internal
        view
        returns (bool _exists)
    {
        if (account == EMPTY) return false;
        if (account == self.root) return true;
        if (self.nodes[account].parent != EMPTY) return true;
        return false;
    }

    function getNode(Tree storage self, address account)
        internal
        view
        returns (
            uint256 _id,
            uint256 _level,
            uint256 _height,
            address _referrer
        )
    {
        Node storage gn = self.nodes[account];
        return (gn.id, gn.level, gn.height, gn.referrer);
    }

    function getNodeStats(Tree storage self, address account)
        internal
        view
        returns (uint256 _partners, uint256 _rewardsRefTotal)
    {
        Node storage gn = self.nodes[account];
        return (gn.partners, gn.rewardsTotal);
    }

    function getNodeStatsInDay(
        Tree storage self,
        address account,
        uint256 day
    ) internal view returns (uint256 _rewardsRef) {
        Node storage gn = self.nodes[account];
        return (gn.rewards[day]);
    }

    function insertNode(
        Tree storage self,
        address referrer,
        address account
    ) internal {
        require(!isContract(account), "Cannot be a contract");

        self.count++;
        self.ids[self.count] = account;

        Node storage newNode = self.nodes[account];
        newNode.id = self.count;
        newNode.level = 0;
        newNode.height = self.nodes[referrer].height + 1;
        newNode.referrer = referrer;
        newNode.partners = 0;

        emit Registration(account, newNode.referrer, newNode.id);
    }

    function setNodeLevel(
        Tree storage self,
        address account,
        uint256 level
    ) internal {
        emit LevelChange(account, self.nodes[account].level, level);
        self.nodes[account].level = level;
    }

    function addNodeRewardsRef(
        Tree storage self,
        address account,
        uint256 value
    ) internal {
        uint256 day = getCurrentDay(self);
        Node storage gn = self.nodes[account];
        gn.rewardsTotal += value;
        gn.rewards[day] += value;
    }

    function addTreeRewardsRef(Tree storage self, uint256 value) internal {
        uint256 day = getCurrentDay(self);
        self.rewardsTotal += value;
        self.rewards[day] += value;
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
                referrer.transfer(c);
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

    function sum(uint256[] memory data) internal pure returns (uint256 s) {
        for (uint256 i; i < data.length; i++) {
            s += data[i];
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a < b) return a;
        else return b;
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
