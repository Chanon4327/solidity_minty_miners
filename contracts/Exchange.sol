// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./AsaToken.sol";
import "./HawKoin.sol";
import "./KorthCoin.sol";

contract Exchange {

    // create instances of all tokens
    // AsaToken public asa; 
    // HawKoin public hawk; 
    // KorthCoin public korth; 

    address public owner;

    ERC20 public token;

    constructor(address _erc20token) {
        owner = msg.sender;
        token = ERC20(_erc20token);
    }

    uint totalLiquidityPositions = 0;
    uint contractERC20TokenBalance = 0; // to store ERC20
    uint contractEthBalance = 0; // to store Ether
    uint K = 0;
    mapping(address => uint) liquidityPositions;

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
    function provideLiquidity(uint _amountERC20Token) public payable returns  (uint) {


        if (totalLiquidityPositions == 0) {
            totalLiquidityPositions = 100;
        } 
        else {
            totalLiquidityPositions = (totalLiquidityPositions * _amountERC20Token) / contractERC20TokenBalance;
        }



        contractEthBalance += msg.value; // new contract EthBalance

        require( token.transferFrom(msg.sender, address(this), _amountERC20Token) ); // recieve erc-20
        contractERC20TokenBalance += _amountERC20Token; // new contract ERCBalance

        K += (contractEthBalance * contractERC20TokenBalance);

        return totalLiquidityPositions;

    }

    function estimateEthToProvide(uint _amountERC20Token) public returns (uint) {
        uint amountETH = contractEthBalance * _amountERC20Token/contractERC20TokenBalance;
        return amountETH;
    }
    /*
    – Users who want to provide liquidity won’t know the current ratio of the tokens in the contract so
    they’ll have to call this function to find out how much ERC-20 token to deposit if they want to
    deposit an amount of Ether
    – Return a uint of the amount of ERC20 token to provide to match the ratio in the contract if the
    caller wants to provide a given amount of Ether
    Use the above to get amountERC20 =
    contractERC20TokenBalance * amountEth/contractEthBalance)
    */
    function estimateERC20TokenToProvide(uint _amountEth) public view returns (uint t) {
        return ( contractERC20TokenBalance *  _amountEth )/contractEthBalance;
    }

    function withdrawLiquidity(uint _liquidityPositionsToBurn) public returns (uint, uint) {
        uint amountEthToSend;
        uint amountERC20ToSend;

        require( _liquidityPositionsToBurn <= totalLiquidityPositions); // Caller shouldn’t be able to give up all the liquidity positions in the pool

        amountEthToSend = (_liquidityPositionsToBurn * contractEthBalance) / totalLiquidityPositions;
        amountERC20ToSend = (_liquidityPositionsToBurn * contractERC20TokenBalance) / totalLiquidityPositions;

        // Transfer Ether from contract to caller
        require( token.transferFrom(address(this), msg.sender, amountEthToSend) ); 
        require( token.transferFrom(address(this), msg.sender, amountERC20ToSend) ); 
    
        totalLiquidityPositions -= _liquidityPositionsToBurn; // Decrement the caller’s liquidity positions and the total liquidity positions
        K += (contractEthBalance * contractERC20TokenBalance); // update k

        return (amountEthToSend, amountERC20ToSend);
    }

    /*
    - Return a uint of the amount of the caller’s liquidity positions (the uint associated to the address
    calling in your liquidityPositions mapping) for when a user wishes to view their liquidity positions
    */

    function getMyLiquidityPositions() view public returns (uint) { 
        // Return the liquidity position of the caller
        return liquidityPositions[msg.sender];
    }

}
