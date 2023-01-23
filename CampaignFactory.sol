// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPancakeRouter02.sol";
import "./GivePoint.sol";
import "./Campaign.sol";

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

    address nativeToken = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address stableToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address dexRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address devAccount = 0x84361F0e0fC4B4eA94B137dB7EF69537a19aCb69;
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

    function setDexRouterAddr(address addr) external onlyOwner{
        dexRouter = addr;
    }

    function getDexRouter() public view returns(address){
        return dexRouter;
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

    function getNativePriceOnUSD(uint256 value) public view returns(uint256) {        
        address[] memory path = new address[](2);
        path[0] = nativeToken;
        path[1] = stableToken;

        uint256 price = IPancakeRouter02(dexRouter).getAmountsOut(value, path)[1];
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
