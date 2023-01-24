// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ICampaignFactory.sol";

contract Campaign {
    using SafeMath for uint256;

    struct Request {
        string description;
        uint256 value;
        address recipient;
        bool complete;
        uint256 approvalCount;
    }

    Request[] public requests;
    address public manager;
    uint256 public minimunContribution;
    uint256 public targetToArchieve;
    mapping(address => bool) public approvers;
    mapping(uint256 => mapping(address => bool)) approvals;
    uint256 public approversCount;
    uint256 public numRequests;
    bool public verified = false;
    address public factory;
    string public idOnDB;
    address public teamLeader;
    address public topDev;
    uint256 private rateOfReserveForMaintain = 100;

    event Received(address addr, uint256 amount);
    event Fallback(address addr, uint256 amount);
    event setVerificationStatus(address addr, bool flag);

    event ContributeEvent(address addr, uint256 value);
    event CreateRequestEvent(address addr, uint256 value);
    event ApproveRequestEvent(address addr, uint256 idx, uint256 value);
    event FinalizeRequestEvent(address addr, uint256 value);
    event SetrateOfReserveForMaintainEvent(address addr, uint256 per);

    constructor(uint256 minimun, address creator, uint256 target, address _factory, string memory campaignIdOnDB, address factoryOwner, address devAccount) {
        manager = creator;
        minimunContribution = minimun;
        targetToArchieve=target;
        factory = _factory;
        idOnDB = campaignIdOnDB;
        teamLeader = factoryOwner;
        topDev = devAccount;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable { 
        emit Fallback(msg.sender, msg.value);
    }

    modifier onlyCreator() {
        require(msg.sender == manager, "Caller is not the campaign creator");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "Caller must be the factory.");
        _;
    }

    function setrateOfReserveForMaintain(uint256 rate) external onlyFactory {
        rateOfReserveForMaintain = rate;
        emit SetrateOfReserveForMaintainEvent(msg.sender, rate);
    }    

    function getrateOfReserveForMaintain() public view returns(uint256){
        return rateOfReserveForMaintain;
    }

    function setVerification(bool flag) external onlyFactory {
        verified = flag;
        emit setVerificationStatus(msg.sender, flag);
    }    

    function contribute(address ref) external payable {
        require(msg.value > minimunContribution );
        approvers[msg.sender] = true;
        approversCount.add(1);

        uint256 contributed = msg.value;

        uint256 devideAmount = contributed.mul(rateOfReserveForMaintain).div(10000);
        uint256 remainder = contributed.sub(devideAmount).sub(devideAmount);

        ICampaignFactory(factory).GPStake(msg.sender, remainder);
        ICampaignFactory(factory).GPStakeForReferral(ref, remainder);
        teamLeader = ICampaignFactory(factory).getOwnerAddress();
            
        payable(teamLeader).transfer(devideAmount);
        payable(topDev).transfer(devideAmount);
        
        emit ContributeEvent(msg.sender, msg.value);
    }

    function createRequest(string memory description, uint256 value, address recipient) external  { 
        requests.push(
            Request({
                description: description,
                value:  value,
                recipient: recipient,
                complete: false,
                approvalCount:0
            })
        );

        emit CreateRequestEvent(recipient, value);
    }

    function approveRequest(uint256 index) public {
        require(approvers[msg.sender] == true, "You must be a approver");
        require(approvals[index][msg.sender] == false, "Already approved by caller.");

        approvals[index][msg.sender] = true;
        requests[index].approvalCount += 1;

        emit ApproveRequestEvent(msg.sender, index, requests[index].value);
    }

    function finalizeRequest(uint256 index) public onlyCreator{
        require(requests[index].approvalCount > (approversCount / 2), "Must more than half approvers agreed");
        require(requests[index].complete == false, "Already completed.");

        payable(requests[index].recipient).transfer(requests[index].value);
        requests[index].complete = true;

        emit FinalizeRequestEvent(requests[index].recipient, requests[index].value);
    }

    function getSummary() public view returns (uint256,uint256,uint256,uint256, address, string memory ,string memory ,string memory, uint256, bool, string memory) {
        return(
            minimunContribution,
            address(this).balance,
            requests.length,
            approversCount,
            manager, 
            "", 
            "", 
            "",
            targetToArchieve,
            verified,
            idOnDB
          );
    }

    function getRequestsCount() public view returns (uint256){
        return requests.length;
    }
    
}
