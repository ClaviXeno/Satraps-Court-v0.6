// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract DecreeMinter is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    IERC721Receiver
{
    constructor(address _chairman) ERC721("Decree", "DCRE") {
        chairman = _chairman;
    }

    address public chairman;
    address public coreAddress;
    uint256 private _nextTokenId = 1;

    mapping(uint256 => uint256) private _tokenSessionIds;

    function setCore(address _coreAddress) external {
        require(msg.sender == chairman, "Error: Sender is not Chairman.");
        coreAddress = _coreAddress;
    }

    function mint(uint256 sessionId, string memory _tokenURI) external {
        uint256 newTokenId = _nextTokenId;

        require(msg.sender == coreAddress, "Error: Sender is not Core.");

        _safeMint(address(this), newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _setTokenSessionId(newTokenId, sessionId);
        _nextTokenId++;
    }

    function _setTokenSessionId(uint256 tokenId, uint256 sessionId) internal {
        _tokenSessionIds[tokenId] = sessionId;
    }

    function getSessionId(uint256 tokenId) public view returns (uint256) {
        return _tokenSessionIds[tokenId];
    }

    //Functions required by solidity

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // The following functions are overrides required by Solidity.
    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
