// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Operations.sol";

/// @title Fluidex events
interface Events {
    event NewToken(address tokenAddr, uint16 tokenId);
    event NewTradingPair(uint16 baseTokenId, uint16 quoteTokenId);
    event RegisterUser(address ethAddr, uint16 userId, string bjjPubkey);
    event Deposit(uint16 tokenId, string to, uint256 amount); // emit tokenId or tokenAddr?
    event Withdraw(uint16 tokenId, address to, uint256 amount); // emit tokenId or tokenAddr?

    /// @notice New priority request event. Emitted when a request is placed into mapping
    event NewPriorityRequest(
        address sender,
        uint64 serialId,
        Operations.OpType opType,
        bytes pubData,
        uint256 expirationBlock
    );
}
