// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

import "./Utils.sol";

import "./Storage.sol";
import "./UserInfo.sol";
import "./Config.sol";
import "./Events.sol";

import "./Operations.sol";

// 2021.01.05: Currently this is only a `mock` contract used to test Fluidex website.
contract Fluidex is ReentrancyGuard, Storage, Config, Events, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint16 constant TOKEN_NUM_LIMIT = 65535;
    uint16 constant USER_NUM_LIMIT = 65535;

    uint16 public tokenNum;
    mapping(uint16 => address) public tokenIdToAddr;
    mapping(address => uint16) public tokenAddrToId;

    uint16 public userNum;
    mapping(uint16 => UserInfo) public userIdToUserInfo;
    mapping(string => uint16) public userBjjPubkeyToUserId;

    function initialize() external {}

    function addToken(address tokenAddr)
        external
        nonReentrant
        returns (uint16)
    {
        tokenNum++;
        require(tokenAddrToId[tokenAddr] == 0, "token existed");
        require(tokenNum < TOKEN_NUM_LIMIT, "token num limit reached");

        uint16 tokenId = tokenNum;
        tokenIdToAddr[tokenId] = tokenAddr;
        tokenAddrToId[tokenAddr] = tokenId;
        // TODO: emit token submitter and token name?
        emit NewToken(tokenAddr, tokenId);
        return tokenId;
    }

    function addTradingPair(uint16 baseTokenId, uint16 quoteTokenId)
        external
        nonReentrant
    {
        // TODO: check valid quote token id. We may support only several quote tokens like USDC and DAI.
        // TODO: maintain map in store
        emit NewTradingPair(baseTokenId, quoteTokenId);
    }

    // TODO: check signature?
    function registerUser(address ethAddr, string memory bjjPubkey) internal {
        userNum++;
        require(userBjjPubkeyToUserId[bjjPubkey] == 0, "user existed");
        require(userNum < USER_NUM_LIMIT, "user num limit reached");

        uint16 userId = userNum;
        userIdToUserInfo[userId] = UserInfo({
            ethAddr: ethAddr,
            bjjPubkey: bjjPubkey
        });
        userBjjPubkeyToUserId[bjjPubkey] = userId;
        emit RegisterUser(ethAddr, userId, bjjPubkey);
    }

    // 0 tokenId means native ETH coin
    // TODO: zkSync uses uint128 for amount
    function registerDeposit(uint16 tokenId, string memory to, uint256 amount) internal {
        // Priority Queue request
        Operations.Deposit memory op =
            Operations.Deposit({
                accountId: 0, // unknown at this point
                owner: to,
                tokenId: tokenId,
                amount: amount
            });
        bytes memory pubData = Operations.writeDepositPubdataForPriorityQueue(op);
        addPriorityRequest(Operations.OpType.Deposit, pubData);
        emit Deposit(tokenId, to, amount);
    }

    /// @param to the L2 address of the deposit target.
    function depositETH(
        string calldata to // L2 bjjPubkey
    ) external payable {
        // You must `approve` the allowance before calling this method

        if (userBjjPubkeyToUserId[to] == 0) {
            registerUser(msg.sender, to);
        }

        // 0 tokenId means native ETH coin
        registerDeposit(0, to, msg.value);
    }

    /// @param to the L2 address of the deposit target.
    /// @param amount the deposit amount.
    function depositERC20(
        IERC20 token,
        string calldata to, // L2 bjjPubkey
        uint128 amount
    ) external nonReentrant {
        // You must `approve` the allowance before calling this method

        uint16 tokenId = tokenAddrToId[address(token)];
        require(tokenId != 0, "invalid token");

        if (userBjjPubkeyToUserId[to] == 0) {
            registerUser(msg.sender, to);
        }

        uint256 balanceBeforeDeposit = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfterDeposit = token.balanceOf(address(this));
        uint256 realAmount = balanceAfterDeposit.sub(balanceBeforeDeposit);
        registerDeposit(tokenId, to, realAmount);
    }

    // debug purpose only, therefore we don't check balance
    function withdrawERC20(
        IERC20 token,
        address to,
        uint128 amount
    ) external nonReentrant {
        require(to != address(0), "invalid address");
        uint16 tokenId = tokenAddrToId[address(token)];
        require(tokenId != 0, "invalid token");
        uint256 balanceBeforeWithdraw = token.balanceOf(address(this));
        token.safeTransfer(to, amount);
        uint256 balanceAfterWithdraw = token.balanceOf(address(this));
        uint256 realAmount = balanceBeforeWithdraw.sub(balanceAfterWithdraw);
        emit Withdraw(tokenId, to, realAmount);
    }

    // debug purpose only, therefore we don't check balance
    function withdrawETH(
        address payable to,
        uint128 amount
    ) external nonReentrant {
        require(to != address(0), "invalid address");
        (bool success, ) = to.call{value: amount}("");
        require(success, "withdrawETH"); // ETH withdraw failed
        emit Withdraw(0, to, amount);
    }

    /// @notice Saves priority request in storage
    /// @dev Calculates expiration block for request, store this request and emit NewPriorityRequest event
    /// @param opType Rollup operation type
    /// @param pubData Operation pubdata
    function addPriorityRequest(Operations.OpType opType, bytes memory pubData) internal {
        // Expiration block is: current block number + priority expiration delta
        uint64 expirationBlock = uint64(block.number + PRIORITY_EXPIRATION);
        uint64 nextPriorityRequestId = firstPriorityRequestId + totalOpenPriorityRequests;
        bytes20 hashedPubData = Utils.hashBytesToBytes20(pubData);
        priorityRequests[nextPriorityRequestId] = PriorityOperation({
            hashedPubData: hashedPubData,
            expirationBlock: expirationBlock,
            opType: opType
        });
        emit NewPriorityRequest(msg.sender, nextPriorityRequestId, opType, pubData, uint256(expirationBlock));
        totalOpenPriorityRequests++;
    }
}
