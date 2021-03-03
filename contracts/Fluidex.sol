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

// 2021.01.05: Currently this is only a `mock` contract used to test Fluidex website.
contract Fluidex is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event NewToken(address tokenAddr, uint16 tokenId);
    event NewTradingPair(uint16 baseTokenId, uint16 quoteTokenId);
    event Deposit(uint16 tokenId, address to, uint256 amount); // emit tokenId or tokenAddr?
    event Withdraw(uint16 tokenId, address to, uint256 amount); // emit tokenId or tokenAddr?

    uint16 constant TOKEN_NUM_LIMIT = 65535;

    uint16 public tokenNum;
    mapping(uint16 => address) public tokenIdToAddr;
    mapping(address => uint16) public tokenAddrToId;

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

    // 0 tokenId means native ETH coin
    // TODO: use uint256 for amount?
    function registerDeposit(uint16 tokenId, address to, uint256 amount) internal {
        // TODO: addPriorityRequest

        emit Deposit(tokenId, to, amount);
    }

    /// @param to the L2 address of the deposit target.
    // TODO: change to L2 address
    function depositETH(address to) external payable {
        // You must `approve` the allowance before calling this method
        require(to != address(0), "invalid address");
        // 0 tokenId means native ETH coin
        registerDeposit(0, to, msg.value);
    }

    /// @param to the L2 address of the deposit target.
    /// @param amount the deposit amount.
    function depositERC20(
        IERC20 token,
        address to, // TODO: change to L2 address
        uint128 amount
    ) external nonReentrant {
        // You must `approve` the allowance before calling this method
        require(to != address(0), "invalid address");
        uint16 tokenId = tokenAddrToId[address(token)];
        require(tokenId != 0, "invalid token");
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
    ) external nonReentrant onlyOwner {
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
    ) external nonReentrant onlyOwner {
        require(to != address(0), "invalid address");
        (bool success, ) = to.call{value: amount}("");
        require(success, "withdrawETH"); // ETH withdraw failed
        emit Withdraw(0, to, amount);
    }
}
