// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

pragma experimental ABIEncoderV2;

/// @title Fluidex operations tools
library Operations {
    /// @notice Fluidex circuit operation type
    enum OpType {
        Deposit
    }

    // Deposit pubdata
    struct Deposit {
        // uint8 opType
        uint32 accountId;
        uint16 tokenId;
        uint256 amount; // TODO: zkSync uses uint128 for amount
        // address owner;
        string owner;
    }

    /// Serialize deposit pubdata
    function writeDepositPubdataForPriorityQueue(Deposit memory op) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            uint8(OpType.Deposit),
            bytes4(0), // accountId (ignored) (update when ACCOUNT_ID_BYTES is changed)
            op.tokenId, // tokenId
            op.amount, // amount
            op.owner // owner
        );
    }
}
