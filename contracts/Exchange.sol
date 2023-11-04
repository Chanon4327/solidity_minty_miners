// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./AsaToken.sol";
import "./HawKoin.sol";
import "./KorthCoin.sol";

contract Exchange {

    // create instances of all tokens
    AsaToken public asa; 
    HawKoin public hawk; 
    KorthCoin public korth; 

    address public user;
    constructor() {
        user = msg.sender;
    }

    uint totalLiquidityPositions = 0;
    uint contractERC20TokenBalance = 0; // to store ERC20
    uint contractEthBalance = 0; // to store Ether
    uint K = 0; 

    /*
    – Caller deposits Ether and ERC20 token in ratio equal to the current ratio of tokens in the contract
    and receives liquidity positions (that is:
    totalLiquidityPositions * amountERC20Token/contractERC20TokenBalance ==
    totalLiquidityPositions *amountEth/contractEthBalance)
    – Transfer Ether and ERC-20 tokens from caller into contract
    – If caller is the first to provide liquidity, give them 100 liquidity positions
    – Otherwise, give them liquidityPositions =
    totalLiquidityPositions * amountERC20Token / contractERC20TokenBalance
    – Update K: K = newContractEthBalance * newContractERC20TokenBalance
    – Return a uint of the amount of liquidity positions issued
    */
    function provideLiquidity(uint _amountERC20Token) public returns  (uint) {

        if (totalLiquidityPositions == 0) {
            totalLiquidityPositions = 100;
        } 
        else {
            totalLiquidityPositions = (totalLiquidityPositions * _amountERC20Token) / contractERC20TokenBalance;
        }

        contractEthBalance += user.balance; // new contract EthBalance

        require( asa.transferFrom(user, address(this), _amountERC20Token) );
        require( hawk.transferFrom(user, address(this), _amountERC20Token) );
        require( korth.transferFrom(user, address(this), _amountERC20Token) );
        contractERC20TokenBalance += _amountERC20Token; // new contract ERCBalance

        K += (contractEthBalance * contractERC20TokenBalance);

        return totalLiquidityPositions;

    }

    function estimateEthToProvide(uint _amountERC20Token) public returns (uint) { }

}