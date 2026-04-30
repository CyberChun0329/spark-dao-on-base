// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IResearchPositionToken {
    function mint(address to, uint256 tokenId) external;
    function protocolTransfer(address from, address to, uint256 tokenId) external;
}
