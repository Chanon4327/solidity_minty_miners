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

    event LiquidityProvided(uint amountERC20TokenDeposited, uint amountEthDeposited, uint liquidityPositionsIssued);
    event LiquidityWithdrew(uint amountERC20TokenWithdrew, uint amountEthWithdrew, uint liquidityPositionsBurned);
    event SwapForEth(uint amountERC20TokenDeposited, uint amountEthWithdrew);
    event SwapForERC20Token(uint amountERC20TokenWithdrew, uint amountEthDeposited);


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


    require( token.transferFrom(msg.sender, address(this), _amountERC20Token), "Unable to recieve ERC20" ); // recieve erc-20
    // technically susceptible to re-entrancy, but it would just steal all their money up to the limit so... why?

        // positiong to give
        uint toGive;

        if (totalLiquidityPositions == 0) {
            // default of 100
            toGive = 100;

            // increment total
            totalLiquidityPositions += 100;
        } 
        else {
            // calculated method
            toGive = (totalLiquidityPositions * _amountERC20Token) / contractERC20TokenBalance;
            // increment total
            totalLiquidityPositions += toGive;
        }

        // save liquidity of the sender
        liquidityPositions[msg.sender] = liquidityPositions[msg.sender] + toGive;



        contractEthBalance += msg.value; // new contract EthBalance

        contractERC20TokenBalance += _amountERC20Token; // new contract ERCBalance

        K += (contractEthBalance * contractERC20TokenBalance);

        emit LiquidityProvided(_amountERC20Token, msg.value, toGive);

        return totalLiquidityPositions;

    }

    function estimateEthToProvide(uint _amountERC20Token) public view returns (uint) {
        return contractEthBalance * _amountERC20Token/contractERC20TokenBalance;
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
    /*  
    – Caller gives up some of their liquidity positions and receives some Ether and ERC20 tokens in
    return.
    Use the above to get
    amountEthToSend = liquidityPositionsToBurn*contractEthBalance / totalLiquidityPositions
    and
    amountERC20ToSend =
        liquidityPositionsToBurn * contractERC20TokenBalance / totalLiquidityPositions
    – Decrement the caller’s liquidity positions and the total liquidity positions
    – Caller shouldn’t be able to give up more liquidity positions than they own
    – Caller shouldn’t be able to give up all the liquidity positions in the pool
    – Update K: K = newContractEthBalance * newContractERC20TokenBalance
    – Transfer Ether and ERC-20 from contract to caller
    – Return 2 uints, the amount of ERC20 tokens sent and the amount of Ether sent
    */

    function withdrawLiquidity(uint _liquidityPositionsToBurn) public returns (uint, uint) {
        require( _liquidityPositionsToBurn <= totalLiquidityPositions, "Unable to burn all liquidity"); // Caller shouldn’t be able to give up all the liquidity positions in the pool
        require(_liquidityPositionsToBurn <= liquidityPositions[msg.sender], "Unable to burn more than owned");
        uint amountEthToSend;
        uint amountERC20ToSend;

        amountEthToSend = (_liquidityPositionsToBurn * contractEthBalance) / totalLiquidityPositions;
        amountERC20ToSend = (_liquidityPositionsToBurn * contractERC20TokenBalance) / totalLiquidityPositions;



        contractEthBalance -= amountEthToSend; // decrement eth to send
        amountERC20ToSend -= amountERC20ToSend; // decrement erc 20 to send
        
        // State is updated before payments to prevent re-entrancy
        liquidityPositions[msg.sender] = liquidityPositions[msg.sender] - _liquidityPositionsToBurn;
        totalLiquidityPositions -= _liquidityPositionsToBurn; // Decrement the caller’s liquidity positions and the total liquidity positions
        K = (contractEthBalance * contractERC20TokenBalance); // update k

        // Transfer Ether from contract to caller
        payable(msg.sender).transfer(amountEthToSend); 
        require( token.transferFrom(address(this), msg.sender, amountERC20ToSend), "Unable to send ERC20" ); 

        emit LiquidityWithdrew(amountERC20ToSend, amountEthToSend, _liquidityPositionsToBurn);

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

    /* swapForEth(uint _amountERC20Token)
    – Caller deposits some ERC20 token in return for some Ether
    – hint: ethToSend = contractEthBalance - contractEthBalanceAfterSwap
    where contractEthBalanceAfterSwap = K / contractERC20TokenBalanceAfterSwap
    – Transfer ERC-20 tokens from caller to contract
    – Transfer Ether from contract to caller
    – Return a uint of the amount of Ether sent
    */
    function swapForEth(uint _amountERC20Token) public returns (uint) {
        // get erc20 from caller
        require ( token.transferFrom(msg.sender, address(this), _amountERC20Token), "Unable to recieve ERC20" );

        // state changes
        contractERC20TokenBalance += _amountERC20Token;
        uint contractEthBalanceAfterSwap = K / contractERC20TokenBalance;
        uint ethToSend = contractEthBalance - contractEthBalanceAfterSwap;

        // withdrawing $$$

        // update ethbalance before withdrawal, prevent re-entracy
        contractEthBalance = contractEthBalanceAfterSwap;


        payable(msg.sender).transfer(ethToSend);

        emit SwapForEth(_amountERC20Token, ethToSend);

        return ethToSend;
    }

    /* 
    -estimates the amount of Ether to give caller based on amount ERC20 token caller wishes to swap
    for when a user wants to know how much Ether to expect when calling swapForEth
    – hint: ethToSend = contractEthBalance-contractEthBalanceAfterSwap where contractEthBalanceAfterSwap = K/contractERC20TokenBalanceAfterSwap
    – Return a uint of the amount of Ether caller would receive*/
    function estimateSwapForEth(uint _amountERC20Token) public view returns (uint) {
        return (contractEthBalance-(K / (contractERC20TokenBalance - _amountERC20Token)));
    }

    /*
    Caller deposits some Ether in return for some ERC20 tokens
    – hint: ERC20TokenToSend = contractERC20TokenBalance - contractERC20TokenBalanceAfterSwap
        where contractERC20TokenBalanceAfterSwap = K /contractEthBalanceAfterSwap
    – Transfer Ether from caller to contract
    – Transfer ERC-20 tokens from contract to caller
    – Return a uint of the amount of ERC20 tokens sent
    */
    function swapForERC20Token() public payable  returns (uint) {
        require(msg.value > 0, "Wei cannot be equal to or less than 0");

        // add ether to bal
        contractEthBalance += msg.value;



        // calculate token to send
        uint contractERC20TokenBalanceAfterSwap = K / contractEthBalance;
        uint ERC20TokenToSend = contractERC20TokenBalance - contractERC20TokenBalanceAfterSwap;


        // update erc20 balance
        contractERC20TokenBalance = contractERC20TokenBalanceAfterSwap;

        // send erc20
        require( token.transferFrom(address(this), msg.sender, ERC20TokenToSend));

        emit SwapForERC20Token(ERC20TokenToSend, msg.value);

        return ERC20TokenToSend;

    }
    /*
    – estimates the amount of ERC20 token to give caller based on amount Ether caller wishes to
        swap for when a user wants to know how many ERC-20 tokens to expect when calling swapForERC20Token
    – hint: ERC20TokenToSend = contractERC20TokenBalance - contractERC20TokenBalanceAfterSwap
        where contractERC20TokenBalanceAfterSwap = K /contractEthBalanceAfterSwap
    – Return a uint of the amount of ERC20 tokens caller would receive
    */

    function estimateSwapForERC20Token(uint _amountEth) public view returns (uint) {
        return contractERC20TokenBalance - (K / (contractEthBalance - _amountEth));
    }
}
