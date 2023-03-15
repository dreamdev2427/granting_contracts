// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GivePoint.sol";
import "./Campaign.sol";

/// @title Quoter Interface
/// @notice Supports quoting the calculated amounts from exact input or exact output swaps
/// @dev These functions are not marked view because they rely on calling non-view functions and reverting
/// to compute the result. They are also not gas efficient and should not be called on-chain.
interface IQuoter {
    /// @notice Returns the amount out received for a given exact input swap without executing the swap
    /// @param path The path of the swap, i.e. each token pair and the pool fee
    /// @param amountIn The amount of the first token to swap
    /// @return amountOut The amount of the last token that would be received
    function quoteExactInput(bytes memory path, uint256 amountIn) external returns (uint256 amountOut);

    /// @notice Returns the amount out received for a given exact input but for a swap of a single pool
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param fee The fee of the token pool to consider for the pair
    /// @param amountIn The desired input amount
    /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountOut The amount of `tokenOut` that would be received
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);

    /// @notice Returns the amount in required for a given exact output swap without executing the swap
    /// @param path The path of the swap, i.e. each token pair and the pool fee
    /// @param amountOut The amount of the last token to receive
    /// @return amountIn The amount of first token required to be paid
    function quoteExactOutput(bytes memory path, uint256 amountOut) external returns (uint256 amountIn);

    /// @notice Returns the amount in required to receive the given exact output amount but for a swap of a single pool
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param fee The fee of the token pool to consider for the pair
    /// @param amountOut The desired output amount
    /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountIn The amount required as the input for the swap in order to receive `amountOut`
    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountIn);
}

contract CampaignFactory is Ownable{
    using SafeMath for uint256;

    bool private pause = false;
    address[] public deployedCampaigns;
    
    GivePoint givePointToken;
    mapping( address => uint256 ) gpStakedAmount;
    mapping( address => uint256 ) countOfCampaignsCausedGpStaking;
    mapping( address => uint256)  gpStakedAmountWithRef;
    mapping( address => uint256 ) countOfRefCausedGpStaking;
    mapping( address => uint256 ) gpClaimedTime;
    mapping( address => uint256 ) gpClaimedTimeRef;

    address nativeToken = 0x4200000000000000000000000000000000000006;   //on Optimism
    address stableToken = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;   //USDT on Opimism
    address quoterAddress = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;  //Uniswap v3 quoter on Optimism
    address devAccount = 0x43c9b51B9903312c37A4de77CaC5404b6ecaC218;
    address public GPaddress;

    uint256 gpClaimDuration = 24 * 3600 * 7;
    uint256 gpRatio;
    uint256 gpRatioForReferral;

    event SetContractStatus(address addr, bool pauseValue);

    modifier paused() {
        require(!pause, "Contract is paused");
        _;
    }

    constructor(){
        givePointToken = new GivePoint();
        GPaddress = address(givePointToken);
        gpRatio = 20;
        gpRatioForReferral = 100;
    }

    function getOwnerAddress() external view returns (address){
        return owner();
    }

    function setquoterAddressAddr(address addr) external onlyOwner{
        quoterAddress = addr;
    }

    function getquoterAddress() public view returns(address){
        return quoterAddress;
    }

    function setNativeToken(address newNativeToken) external onlyOwner{
        nativeToken = newNativeToken;
    }

    function getNativeToken() external view returns(address){
        return nativeToken;
    }

    function setDevAccount(address addr) external {
        require(msg.sender == devAccount);
        devAccount = addr;
    }

    function getDevAccount() public view returns(address){
        return devAccount;
    }

    function setStableToken(address newStableToken) external onlyOwner{
        stableToken = newStableToken;
    }

    function getStableToken() external view returns(address){
        return stableToken;
    }

    function setGPRatio(uint256 newRatio) external onlyOwner{
        gpRatio = newRatio;
    }

    function getGPRatio() external view returns(uint256){
        return gpRatio;
    }

    function setGPRatioForReferral(uint256 newRatio) external onlyOwner{
        gpRatioForReferral = newRatio;
    }

    function getGPRatioForReferral() external view returns(uint256){
        return gpRatioForReferral;
    }

    function setGPClaimedDuration(uint256 newDuration) external onlyOwner{
        gpClaimDuration = newDuration;
    }

    function getGPClaimedDuration() external view returns(uint256){
        return gpClaimDuration;
    }

    function getCountOfCampaignsCausedGpStaking(address user) public view returns(uint256){
        return countOfCampaignsCausedGpStaking[user];
    }

    function getStakedAmount(address user) public view returns(uint256){
        return gpStakedAmount[user];
    }
    
    function getStakedAmountWithRef(address user) public view returns(uint256){
        return gpStakedAmountWithRef[user];
    }

    function getCountsOfRefCausedGpStaking(address user) public view returns(uint256){
        return countOfRefCausedGpStaking[user];
    }

    function GPClaim(address user) external{
        
        uint256 value = gpStakedAmount[user];
        
        require( gpClaimedTime[user] + gpClaimDuration > block.timestamp, "Less then claiming period" );
        require( value > 0, "Value should be a positive number" );

        gpClaimedTime[user] = block.timestamp;
        
        givePointToken.mint( user, value );
        gpStakedAmount[user] = 0;
        countOfCampaignsCausedGpStaking[user] = 0;
    }

    function GPClaimRef(address user) external{
        
        uint256 value = gpStakedAmountWithRef[user];
        
        require( gpClaimedTimeRef[user] + gpClaimDuration > block.timestamp, "Less then claiming period" );
        require( value > 0, "Value should be a positive number." );

        gpClaimedTimeRef[user] = block.timestamp;
        
        givePointToken.mint( user, value );
        gpStakedAmountWithRef[user] = 0;
        countOfRefCausedGpStaking[user] = 0;
    }

    function getNativePriceOnUSD(uint256 value) public returns(uint256) {      

        uint256 price = IQuoter(quoterAddress).quoteExactInputSingle(nativeToken, stableToken, 100, value, 0);
        return price;
    }

    function GPStake(address user, uint256 value) external{        
        uint256 idx; bool isExist = false;
        for(idx=0; idx<deployedCampaigns.length; idx++)
        {
            if(deployedCampaigns[idx] == msg.sender)
            {
                isExist = true;
            }
        }   
        require(isExist == true, "Cannot be staked from undeployed campaign");

        uint256 price = getNativePriceOnUSD(value);
        gpStakedAmount[user].add(price.div(gpRatio));
        gpClaimedTime[user] = block.timestamp;
        countOfCampaignsCausedGpStaking[user].add(1);
    }

    function GPStakeForReferral(address ref, uint256 value) external{
        uint256 idx; bool isExist = false;
        for(idx=0; idx<deployedCampaigns.length; idx++)
        {
            if(deployedCampaigns[idx] == msg.sender)
            {
                isExist = true;
            }
        }   
        require(isExist == true, "Cannot be staked from undeployed campaign");

        uint256 price = getNativePriceOnUSD(value);
        gpStakedAmountWithRef[ref].add(price.div(gpRatioForReferral));
        gpClaimedTimeRef[ref] = block.timestamp;
        countOfRefCausedGpStaking[ref].add(1);
    }

    function getContractStatus() external view returns (bool) {
        return pause;
    }
    
    function setContractStatus(bool _newPauseContract) external onlyOwner {
        pause = _newPauseContract;
        emit SetContractStatus(msg.sender, _newPauseContract);
    }

    function createCampaign(uint256 minimum, uint256 target, string memory idOnDB) public paused returns(address) {
        address newCampaign = address(new Campaign(minimum, msg.sender, target, address(this), idOnDB, owner(), devAccount ));
        deployedCampaigns.push(newCampaign);
        return newCampaign;
    }

    function getDeployedCampaigns() public view returns (address[] memory) {
        return deployedCampaigns;
    }
    
    function setVerification(address payable campaignAddr, bool flag) external onlyOwner {
        Campaign one = Campaign(campaignAddr);
        one.setVerification(flag);
    }
}
