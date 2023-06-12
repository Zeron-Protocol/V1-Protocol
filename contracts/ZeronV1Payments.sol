// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IZeronV1Router.sol";
import "./interfaces/IZeronV1Arbitral.sol";

contract ZeronV1Payments {

    enum PaymentStatus { Created, InProgress, Submitted, Completed, Cancelled, Rejected, Disputed, Resolved }
    address public immutable router;
    address public immutable arbitral;
    address public immutable employer;
    address public immutable employee;
    address public immutable commissionTokenAddr;
    uint public immutable amount;
    uint private fee;
    bool public unLocked;
    string public task;
    uint public deadline; 
    uint public createdAt; 
    uint public signedAt; 
    uint public submittedAt; 
    uint public completedAt; 
    uint public rejectedAt; 
    uint public cancelledAt; 
    bytes32 disputeId;

    PaymentStatus public status;
    IERC20 public immutable commissionToken;

    struct PaymentDetails {
        address router;
        address arbitral;
        address employer;
        address employee;
        address commissionToken;
        uint amount;
        uint fee;
        uint deadline; 
        uint createdAt; 
        uint signedAt; 
        uint submittedAt; 
        uint completedAt; 
        uint rejectedAt; 
        uint cancelledAt; 
        bool unLocked;
        string task;
        bytes32 disputeId;
        PaymentStatus status;
    }

    event DisputeResolved( address employee,uint256 amount ) ;
    event DisputeStarted( address employee,address employer,uint256 amount,bytes32 disputeId ) ;
    event TaskCancelled( address employer,address employee,uint256 amount,uint256 cancelledAt ) ;
    event TaskCompleted( address employer,address employee,uint256 amount,uint256 completedAt ) ;
    event TaskRejected( address employer,address employee,uint256 amount,uint256 rejectedAt ) ;
    event TaskSigned( address employer,address employee,string task,uint256 signedAt) ;
    event TaskSubmitted( address employer,address employee,string task,uint256 submittedAt ) ;


    constructor(
        address _arbitral,
        address _employer,
        address _employee,
        uint _amount,
        string memory _task,
        uint _deadline,
        address _commissionToken,
        uint _fee
    ) {
        require(_arbitral != address(0), "Invalid arbitral address");
        require(_employer != address(0), "Invalid employer address");
        require(_employee != address(0), "Invalid employee address");
        require(_amount > 0, "Commission should be greater than 0");
        require(_deadline > block.timestamp, "Deadline should be greater than createdAt");
        router = msg.sender;
        arbitral = _arbitral;
        employer = _employer;
        employee = _employee;
        amount = _amount;
        task = _task;
        createdAt = block.timestamp;
        deadline = _deadline;
        commissionTokenAddr = _commissionToken;
        commissionToken = IERC20(_commissionToken);
        fee = _fee;
        status = PaymentStatus.Created;
        unLocked = true;
    }


    modifier unLock() {
        require(unLocked, "Zeron Payment Contract locked");
        _;
    }


    modifier onlyOwner {
        require(msg.sender == IZeronV1Router(router).owner(), "Only Owner can call this function");
        _;
    }


    modifier onlyArbitral {
        require(msg.sender == arbitral, "Only arbitral can call this function");
        _;
    }


    modifier onlyEmployer {
        require(msg.sender == employer, "Only employer can call this function");
        _;
    }


    modifier onlyEmployee {
        require(msg.sender == employee, "Only employee can call this function");
        _;
    }


    function signTask() external unLock onlyEmployee {
        require(status == PaymentStatus.Created, "Task has been signed");

        status = PaymentStatus.InProgress;
        signedAt = block.timestamp;
        emit TaskSigned(employer, employee, task, signedAt);
    }


    function submitTask() external unLock onlyEmployee {
        require(status == PaymentStatus.InProgress, "Task cannot be submitted");

        status = PaymentStatus.Submitted;
        submittedAt = block.timestamp;
        emit TaskSubmitted(employer, employee, task, submittedAt);
    }


    function approveTask() external unLock onlyEmployer {
        require(status == PaymentStatus.Submitted || status == PaymentStatus.Rejected, "Task cannot be approved");

        status = PaymentStatus.Completed;
        commissionToken.transfer(employee, amount * (100 - fee) / 100);
        commissionToken.transfer(router, amount * fee / 100);
        completedAt = block.timestamp;
        emit TaskCompleted(employer, employee, amount, completedAt);
    }


    function rejectTask() external unLock onlyEmployer {
        require(status == PaymentStatus.Submitted, "Task cannot be rejected");

        status = PaymentStatus.Rejected;
        rejectedAt = block.timestamp;
        emit TaskRejected(employer, employee, amount, rejectedAt);
    }


    function refund() external unLock onlyEmployer {
        require(status == PaymentStatus.Created || status == PaymentStatus.InProgress && block.timestamp > deadline + 14 days || status == PaymentStatus.Rejected && block.timestamp > rejectedAt + 60 days, "Cannot refund now");

        commissionToken.transfer(employer, amount * (100 - fee) / 100);
        commissionToken.transfer(router, amount * fee / 100);
        status = PaymentStatus.Cancelled;
        cancelledAt = block.timestamp;
        emit TaskCancelled(employer, employee, amount, cancelledAt);
    }


    function withdrawFund() external unLock onlyEmployee {
        require(status == PaymentStatus.Submitted && block.timestamp > deadline + 14 days, "Cannot withdraw fund now");
        
        status = PaymentStatus.Completed;
        commissionToken.transfer(employee, amount * (100 - fee) / 100);
        commissionToken.transfer(router, amount * fee / 100);
        completedAt = block.timestamp;
        emit TaskCompleted(employer, employee, amount, completedAt);
    }


    function setDispute() external unLock onlyEmployee {
        require(status == PaymentStatus.Rejected, "Task can not be disputed");

        status = PaymentStatus.Disputed;
        disputeId = IZeronV1Arbitral(arbitral).startDispute(employee, employer, commissionTokenAddr, amount, fee);
        emit DisputeStarted(employee, employer, amount, disputeId);
    }


    function resolveDispute(address payable _recipient) external unLock onlyArbitral {
        require(status == PaymentStatus.Disputed, "There is no active dispute");
        
        status = PaymentStatus.Resolved;
        commissionToken.transfer(arbitral, amount * fee / 100);
        commissionToken.transfer(_recipient, amount - amount * fee / 100);
        emit DisputeResolved(_recipient, amount);
        completedAt = block.timestamp;
    }


    function getAllProperties() external view returns (PaymentDetails memory) {
        PaymentDetails memory details;

        details.router = router;
        details.arbitral = arbitral;
        details.employer = employer;
        details.employee = employee;
        details.commissionToken = commissionTokenAddr;
        details.amount = amount;
        details.fee = fee;
        details.deadline = deadline; 
        details.createdAt = createdAt; 
        details.signedAt = signedAt; 
        details.submittedAt = submittedAt; 
        details.completedAt = completedAt; 
        details.rejectedAt = rejectedAt; 
        details.cancelledAt =cancelledAt; 
        details.unLocked = unLocked;
        details.task = task;
        details.disputeId = disputeId;
        details.status = status;

        return details;
    }


    function setPaymentState(bool _isUnLock) external onlyOwner {
        unLocked = _isUnLock;
    }
}
