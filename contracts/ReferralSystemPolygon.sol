// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./lib/ReferralTreeLib.sol";

contract ReferralSystemPolygon is Ownable, Pausable {
    using Address for address;
    using ReferralTreeLib for ReferralTreeLib.Tree;

    ReferralTreeLib.Tree private tree;

    constructor() public {
        //
    }

    // pause
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
