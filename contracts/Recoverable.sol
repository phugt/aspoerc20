pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Recoverable is Ownable {
  function recoverTokens(IERC20 token) public onlyOwner {
    require(token.transfer(owner(), tokensToBeReturned(token)), "Transfer failed");
  }

  function tokensToBeReturned(IERC20 token) public view returns (uint) {
    return token.balanceOf(address(this));
  }
}