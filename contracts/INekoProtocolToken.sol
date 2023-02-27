// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INekoProtocolToken is IERC20 {
    function beckon(address _recipient, uint256 _amount) external;
}
