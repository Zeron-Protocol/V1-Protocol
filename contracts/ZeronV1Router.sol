// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IZeronV1Arbitral.sol";
import "./interfaces/IZeronV1Payments.sol";
import "./ZeronV1Payments.sol";

contract ZeronV1Router {
    address public owner;
    address public arbitral;
    address[] private allZeronPayments;
    uint24 public serviceFee;
    bool public unLocked;
    mapping(address => bool) public supportCommissionTokens;
    mapping(address => address[]) private zeronPaymentsByEmployer;
    mapping(address => address[]) private zeronPaymentsByEmployee;

    event FeeChanged(uint fee);
    event CommisionTokenChanged(address token, bool isSupport);
    event ArbitralChanged(address arbitral);
    event OwnerChanged(address oldOwner, address newOwner);

    constructor() {
        owner = msg.sender;
        serviceFee = 2;
    }


    modifier unLock() {
        require(unLocked, "Zeron Router locked");
        _;
    }


    modifier onlyOwner {
        require(msg.sender == owner, "Only Owner can call this function");
        _;
    }
    

    function createZeronPayments(address _employee, uint256 _amount, string memory _task, uint _duration, address _commisionToken) external unLock returns (address) {
        require(msg.sender != _employee, "Invalid employee address");
        require(_employee != address(0), "Invalid employee address");
        require(supportCommissionTokens[_commisionToken], "Invalid commission token");
        require(_amount > 0, "Commission should be greater than 0");
        require(_duration > 0, "Duration should be greater than 0");
        ZeronV1Payments zeronPayment = new ZeronV1Payments(arbitral, msg.sender, _employee, _amount, _task, _duration, _commisionToken, serviceFee);
        address paymentAddr = address(zeronPayment);
        allZeronPayments.push(paymentAddr);
        zeronPaymentsByEmployer[msg.sender].push(paymentAddr);
        zeronPaymentsByEmployee[_employee].push(paymentAddr);
        // Get ERC20 token contract
        IERC20 commisionToken = IERC20(_commisionToken);
        // Check if the sender has approved the ZeronRoute contract to spend their tokens
        uint256 allowance = commisionToken.allowance(msg.sender, address(this));
        require(allowance >= _amount, "ZeronRoute is not authorized to spend the specified amount of tokens");

        commisionToken.transferFrom(msg.sender, paymentAddr, _amount);

        IZeronV1Arbitral(arbitral).addPayments(paymentAddr);
        return paymentAddr;
    }


    function getZeronPaymentsByEmployee(address _employee) external view returns (address[] memory) {
        return zeronPaymentsByEmployee[_employee];
    }


    function getZeronPaymentsByEmployer(address _employer) external view returns (address[] memory) {
        return zeronPaymentsByEmployer[_employer];
    }


    function getAllZeronPayments() external view returns (address[] memory) {
        return allZeronPayments;
    }


    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit OwnerChanged(owner, _owner);
    }


    function setArbitral(address _arbitral) external onlyOwner {
        arbitral = _arbitral;
        emit ArbitralChanged(arbitral);
    }


    function setFees(uint24 _fee) external onlyOwner {
        serviceFee = _fee;
        emit FeeChanged(_fee);
    }


    function setCommisionToken(address _commisionToken, bool isSupport) external onlyOwner {
        supportCommissionTokens[_commisionToken] = isSupport;
        emit CommisionTokenChanged(_commisionToken, isSupport);
    }


    function withdrawTokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        token.transfer(msg.sender, amount);
    }


    function setRouterState(bool _isUnLock) external onlyOwner {
        unLocked = _isUnLock;
    }
}