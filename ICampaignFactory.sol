// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICampaignFactory {
    function GPStake(address user, uint256 value) external;
    function GPStakeForReferral(address ref, uint256 value) external;
    function getOwnerAddress() external view returns (address);
}