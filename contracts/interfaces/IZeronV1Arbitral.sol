// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IZeronV1Arbitral {
    event DisputeFiled(
        bytes32 disputeId,
        address plaintiff,
        address defendant,
        address zeronPayment,
        uint256 amount
    );
    event DisputeTie(bytes32 disputeId);
    event Voted(bytes32 disputeId, address witness, bool isSupport);
    event WitnessRemoved(address witness);
    event WitnessStaked(address witness);

    function addPayments(address _paymentAddr) external;

    function addWitnesses(address[] memory whitelist, uint256 amount) external;

    function attendanceRewards(address, address)
        external
        view
        returns (uint256);

    function balanceOfStakingRewardsSupply() external view returns (uint256);

    function becomeWitness(uint256 stakingAmount) external;

    function calculateStakingRewards(address witness)
        external
        view
        returns (uint256);

    function claimAttendanceRewards(bytes32 _disputeId) external;

    function disputes(bytes32)
        external
        view
        returns (
            address plaintiff,
            address defendant,
            address zeronPaymentAddr,
            address commisionTokenAddr,
            uint256 disputeCreatedAt,
            uint256 amount,
            uint256 fee,
            uint256 numberOfVotes,
            uint8 status,
            ZeronArbitral.VoteCounter memory voteCounter
        );

    function getDetailOfDispute(bytes32 _disputeId)
        external
        view
        returns (ZeronArbitral.Dispute memory);

    function minStake() external view returns (uint256);

    function owner() external view returns (address);

    function resignWitness() external;

    function resolveDispute(bytes32 _disputeId) external;

    function resolveTiedDispute(bytes32 _disputeId, bool _supportsRuling)
        external;

    function router() external view returns (address);

    function setArbitralState(bool _isUnLock) external;

    function stakingRate() external view returns (uint24);

    function startDispute(
        address _plaintiff,
        address _defendant,
        address _commisionTokenAddr,
        uint256 _amount,
        uint256 _fee
    ) external payable returns (bytes32 disputeId);

    function totalStakingRewardsSupply() external view returns (uint256);

    function unLocked() external view returns (bool);

    function voteDispute(bytes32 _disputeId, bool _supportsRuling) external;

    function withdrawAttendanceRewards(address tokenAddress, uint256 amount)
        external;

    function withdrawTokens(address tokenAddress, uint256 amount) external;

    function witnesses(address)
        external
        view
        returns (
            address witnessAddr,
            uint256 joinedAt,
            uint256 stakingAmount,
            uint256 minStakingAmount,
            uint256 votingShares,
            uint256 winCount,
            uint256 lossCount,
            bool isWitness,
            bool isArbitrator
        );

    function zeronPayments(address) external view returns (bool);

    function zntToken() external view returns (address);
}

interface ZeronArbitral {
    struct VoteCounter {
        uint256 inSupport;
        uint256 inOpposition;
    }

    struct Dispute {
        address plaintiff;
        address defendant;
        address zeronPaymentAddr;
        address commisionTokenAddr;
        address[] attWit;
        uint256 disputeCreatedAt;
        uint256 amount;
        uint256 fee;
        uint256 numberOfVotes;
        uint8 status;
        VoteCounter voteCounter;
    }
}