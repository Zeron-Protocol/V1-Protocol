// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IZeronV1Payments {
    event DisputeResolved(address employee, uint256 amount);
    event DisputeStarted(
        address employer,
        address employee,
        uint256 amount,
        bytes32 disputeId
    );
    event TaskCancelled(
        address employer,
        address employee,
        uint256 amount,
        uint256 cancelledAt
    );
    event TaskCompleted(
        address employer,
        address employee,
        uint256 amount,
        uint256 completedAt
    );
    event TaskRejected(
        address employer,
        address employee,
        uint256 amount,
        uint256 rejectedAt
    );
    event TaskSigned(
        address employer,
        address employee,
        string task,
        uint256 signedAt
    );
    event TaskSubmitted(
        address employer,
        address employee,
        string task,
        uint256 submittedAt
    );

    function amount() external view returns (uint256);

    function approveTask() external;

    function arbitral() external view returns (address);

    function cancelledAt() external view returns (uint256);

    function commissionToken() external view returns (address);

    function commissionTokenAddr() external view returns (address);

    function completedAt() external view returns (uint256);

    function createdAt() external view returns (uint256);

    function deadline() external view returns (uint256);

    function employee() external view returns (address);

    function employer() external view returns (address);

    function getAllProperties()
        external
        view
        returns (ZeronV1Payments.PaymentDetails memory);

    function refund() external;

    function rejectTask() external;

    function rejectedAt() external view returns (uint256);

    function resolveDispute(address _recipient) external;

    function router() external view returns (address);

    function setDispute() external;

    function setPaymentState(bool _isUnLock) external;

    function signTask() external;

    function signedAt() external view returns (uint256);

    function status() external view returns (uint8);

    function submitTask() external;

    function submittedAt() external view returns (uint256);

    function task() external view returns (string memory);

    function unLocked() external view returns (bool);

    function withdrawFund() external;
}

interface ZeronV1Payments {
    struct PaymentDetails {
        address router;
        address arbitral;
        address employer;
        address employee;
        address commissionToken;
        uint256 amount;
        uint256 fee;
        uint256 deadline;
        uint256 createdAt;
        uint256 signedAt;
        uint256 submittedAt;
        uint256 completedAt;
        uint256 rejectedAt;
        uint256 cancelledAt;
        bool unLocked;
        string task;
        bytes32 disputeId;
        uint8 status;
    }
}