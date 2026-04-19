// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

contract TeachingNftToken {
    error UnauthorizedAuthority();
    error UnauthorizedMinter();
    error ZeroAddress();
    error TokenAlreadyMinted();
    error TokenNotFound();
    error NonTransferable();

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event MinterUpdated(address indexed previousMinter, address indexed newMinter);

    bytes4 internal constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 internal constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 internal constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;

    address public immutable AUTHORITY;
    address public minter;
    string public name;
    string public symbol;
    string public baseTokenURI;

    mapping(uint256 tokenId => address owner) internal owners;
    mapping(address owner => uint256 balance) internal balances;

    constructor(
        address authority_,
        string memory name_,
        string memory symbol_,
        string memory baseTokenUri_
    ) {
        if (authority_ == address(0)) revert ZeroAddress();
        AUTHORITY = authority_;
        name = name_;
        symbol = symbol_;
        baseTokenURI = baseTokenUri_;
    }

    modifier onlyAuthority() {
        _onlyAuthority();
        _;
    }

    modifier onlyMinter() {
        _onlyMinter();
        _;
    }

    function setMinter(address newMinter) external onlyAuthority {
        if (newMinter == address(0)) revert ZeroAddress();
        address previousMinter = minter;
        minter = newMinter;
        emit MinterUpdated(previousMinter, newMinter);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == ERC165_INTERFACE_ID || interfaceId == ERC721_INTERFACE_ID
            || interfaceId == ERC721_METADATA_INTERFACE_ID;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = owners[tokenId];
        if (owner == address(0)) revert TokenNotFound();
        return owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return balances[owner];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (owners[tokenId] == address(0)) revert TokenNotFound();
        return string.concat(baseTokenURI, _toString(tokenId));
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (owners[tokenId] == address(0)) revert TokenNotFound();
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function approve(address, uint256) external pure {
        revert NonTransferable();
    }

    function setApprovalForAll(address, bool) external pure {
        revert NonTransferable();
    }

    function transferFrom(address, address, uint256) external pure {
        revert NonTransferable();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert NonTransferable();
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert NonTransferable();
    }

    function mint(address to, uint256 tokenId) external onlyMinter {
        if (to == address(0)) revert ZeroAddress();
        if (owners[tokenId] != address(0)) revert TokenAlreadyMinted();

        owners[tokenId] = to;
        balances[to] += 1;

        emit Transfer(address(0), to, tokenId);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits = 0;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            // forge-lint: disable-next-line(unsafe-typecast)
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _onlyAuthority() internal view {
        if (msg.sender != AUTHORITY) revert UnauthorizedAuthority();
    }

    function _onlyMinter() internal view {
        if (msg.sender != minter) revert UnauthorizedMinter();
    }
}
