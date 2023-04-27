// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IZeronV1Payments.sol";


contract ZeronV1Arbitral {

    enum DisputeStatus { InProgress, Supported, Opposited, Tied }
    enum VoteStatus { Default, Support, Opposition, Claimed }

    struct Witness {
        address witnessAddr;
        uint joinedAt;
        uint stakingAmount;
        uint minStakingAmount;
        uint votingShares;
        uint winCount;
        uint lossCount;
        bool isWitness;
        bool isArbitrator;
    }

    struct VoteCounter {
        uint256 inSupport;
        uint256 inOpposition;
    }

    struct Dispute {
        address payable plaintiff;
        address payable defendant;
        address zeronPaymentAddr;
        address commisionTokenAddr;
        address[] attWit;
        uint disputeCreatedAt;
        uint amount;
        uint fee;
        uint numberOfVotes;
        DisputeStatus status;
        VoteCounter voteCounter;
    }

    address public owner;
    address public router;
    address public zntToken;
    uint public totalStakingRewardsSupply;
    uint public balanceOfStakingRewardsSupply;
    uint public minStake;
    uint24 public stakingRate;
    bool public unLocked;
    mapping (address => bool) public zeronPayments;
    mapping (address => Witness) public witnesses;
    mapping (bytes32 => Dispute) public disputes;
    mapping (bytes32 => mapping(address => VoteStatus)) private witnessesVoteStatus;
    mapping (address => mapping(address => uint)) public attendanceRewards;

    event DisputeFiled(bytes32 disputeId, address plaintiff, address defendant, address zeronPayment, uint amount);
    event WitnessStaked(address witness);
    event WitnessRemoved(address witness);
    event Voted(bytes32 disputeId, address witness, bool isSupport);
    event DisputeTie(bytes32 disputeId);

    constructor(address _router, address _zntToken) {
        owner = msg.sender;
        router = _router;
        zntToken = _zntToken;
        totalStakingRewardsSupply = IERC20(zntToken).totalSupply() * 25 / 100;
        balanceOfStakingRewardsSupply = balanceOfStakingRewardsSupply;
        stakingRate = 4; // 4% per year
        minStake = 150000 * 10 ** 18; // 150,000 ZNT
    }


    modifier unLock() {
        require(unLocked, "Zeron Arbitral locked");
        _;
    }


    modifier onlyOwner {
        require(msg.sender == owner, "Only Owner can call this function");
        _;
    }


    modifier onlyRouter {
        require(msg.sender == router, "Only Router can call this function");
        _;
    }


    modifier onlyArbitrator {
        require(witnesses[msg.sender].isArbitrator, "Only Arbitrator can call this function");
        _;
    }


    modifier onlyWitness {
        require(witnesses[msg.sender].isWitness, "Only Witness can call this function");
        _;
    }


    modifier onlyZeronPayment {
        require(zeronPayments[msg.sender], "Only ZeronPayment Contract can call this function");
        _;
    }


    function addPayments(address _paymentAddr) external onlyRouter {
        zeronPayments[_paymentAddr] = true;
        emit WitnessStaked(msg.sender);
    }


    function calculateStakingRewards(address witness) public view returns (uint256) {
        uint256 stakedAmount = witnesses[witness].stakingAmount;
        uint256 stakeStart = witnesses[witness].joinedAt;

        if (stakedAmount == 0) {
            return 0;
        }
        uint256 secondsOfQuarter = 12 weeks;
        uint256 timeElapsed = block.timestamp - stakeStart;
        uint256 numPeriods = timeElapsed / secondsOfQuarter;
        uint256 rate = stakingRate;
        for (uint256 i = 0; i < numPeriods; i++) {
            rate += rate / 10;
        }

        return (stakedAmount * rate / 100 * timeElapsed) / (365 days);
    }


    function becomeWitness(uint stakingAmount) external unLock {
        require(stakingAmount > minStake, "The staked amount is insufficient");
        require(!witnesses[msg.sender].isWitness, "You are already a witness");
        require(IERC20(zntToken).transferFrom(msg.sender, address(this), stakingAmount), "Insufficient ZNT balance or approval");

        witnesses[msg.sender].witnessAddr = msg.sender;
        witnesses[msg.sender].isWitness = true;
        witnesses[msg.sender].isArbitrator = false;
        witnesses[msg.sender].joinedAt = block.timestamp;
        witnesses[msg.sender].stakingAmount = stakingAmount;
        witnesses[msg.sender].winCount = 0;
        witnesses[msg.sender].lossCount = 0;
        witnesses[msg.sender].votingShares = stakingAmount / minStake;
        witnesses[msg.sender].minStakingAmount = minStake;
        emit WitnessStaked(msg.sender);
    }


    function resignWitness() external unLock onlyWitness {
        uint256 stakingRewards = calculateStakingRewards(msg.sender);
        require(IERC20(zntToken).transfer(msg.sender, witnesses[msg.sender].stakingAmount + stakingRewards), "Failed to transfer ZNT");

        balanceOfStakingRewardsSupply = balanceOfStakingRewardsSupply - stakingRewards;
        delete witnesses[msg.sender];
        emit WitnessRemoved(msg.sender);
    }


    function startDispute(address payable _plaintiff, address payable _defendant, address _commisionTokenAddr, uint _amount, uint _fee) public unLock onlyZeronPayment payable returns (bytes32 disputeId) {
        require(_plaintiff != _defendant, "Plaintiff and defendant cannot be the same");
        require(_plaintiff != address(0) && _defendant != address(0), "Invalid plaintiff or defendant address");
        require(_amount > 0, "Amount must be greater than zero");
        
        disputeId = keccak256(abi.encodePacked(_plaintiff, _defendant, _amount, block.timestamp));
        Dispute memory dispute = disputes[disputeId];
        dispute = Dispute(
            {
                plaintiff: _plaintiff,
                defendant: _defendant,
                commisionTokenAddr: _commisionTokenAddr,
                zeronPaymentAddr: msg.sender,
                attWit: new address[](0),
                disputeCreatedAt: block.timestamp,
                amount: _amount,
                fee: _fee,
                numberOfVotes: 0,
                status: DisputeStatus.InProgress,
                voteCounter: VoteCounter({
                    inSupport: 0,
                    inOpposition: 0
                })
            }
        );
        
        emit DisputeFiled(disputeId, _plaintiff, _defendant, msg.sender, _amount);
        return disputeId;
    }


    function voteDispute(bytes32 _disputeId, bool _supportsRuling) external unLock onlyWitness {
        Dispute storage dispute = disputes[_disputeId];
        require(msg.sender != dispute.plaintiff && msg.sender != dispute.defendant, "Forbidden");
        require(block.timestamp <= dispute.disputeCreatedAt + 14 days, "Dispute has expired");
        require(witnessesVoteStatus[_disputeId][msg.sender] == VoteStatus.Default, "Duplicate voting is not allowed");

        dispute.numberOfVotes = dispute.numberOfVotes + witnesses[msg.sender].votingShares;
        dispute.attWit.push(msg.sender);
        if (_supportsRuling) {
            dispute.voteCounter.inSupport = dispute.voteCounter.inSupport + witnesses[msg.sender].votingShares;
            witnessesVoteStatus[_disputeId][msg.sender] = VoteStatus.Support;
        } else {
            dispute.voteCounter.inOpposition = dispute.voteCounter.inOpposition  + witnesses[msg.sender].votingShares;
            witnessesVoteStatus[_disputeId][msg.sender] = VoteStatus.Opposition;
        }

        emit Voted(_disputeId, msg.sender, _supportsRuling);
    }


    function resolveDispute(bytes32 _disputeId) external unLock {
        Dispute storage dispute = disputes[_disputeId];
        require(msg.sender == dispute.plaintiff || msg.sender == dispute.defendant || witnessesVoteStatus[_disputeId][msg.sender] != VoteStatus.Default, "Dispute still in progress");
        require(block.timestamp > dispute.disputeCreatedAt + 14 days, "Dispute still in progress");
        require(dispute.status == DisputeStatus.InProgress, "Dispute cannot resolved yet");


        address[] memory attWits = dispute.attWit;
        if (dispute.voteCounter.inSupport > dispute.voteCounter.inOpposition) {
            dispute.status = DisputeStatus.Supported;
            IZeronV1Payments(dispute.zeronPaymentAddr).resolveDispute(dispute.plaintiff);
        } else {
            if (dispute.voteCounter.inSupport < dispute.voteCounter.inOpposition) {
                dispute.status = DisputeStatus.Opposited;
                IZeronV1Payments(dispute.zeronPaymentAddr).resolveDispute(dispute.defendant);
            } else {
                dispute.status = DisputeStatus.Tied;
                emit DisputeTie(_disputeId);
            }
        }

        for(uint i=0; i<attWits.length; i++) {
            if ( witnessesVoteStatus[_disputeId][attWits[i]] == VoteStatus.Support && dispute.status == DisputeStatus.Supported || witnessesVoteStatus[_disputeId][attWits[i]] == VoteStatus.Opposition && dispute.status == DisputeStatus.Opposited ) {
                witnesses[attWits[i]].winCount++;
            } else {
                witnesses[attWits[i]].lossCount++;
            }
        }
    }


    function resolveTiedDispute(bytes32 _disputeId, bool _supportsRuling) external unLock onlyArbitrator {
        Dispute storage dispute = disputes[_disputeId];
        require(msg.sender == dispute.plaintiff || msg.sender == dispute.defendant || witnessesVoteStatus[_disputeId][msg.sender] != VoteStatus.Default, "Dispute still in progress");
        require(block.timestamp > dispute.disputeCreatedAt + 14 days, "Dispute still in progress");
        require(dispute.status == DisputeStatus.Tied, "Dispute is not a tied dispute");
        require(dispute.voteCounter.inSupport == dispute.voteCounter.inOpposition, "Dispute is not a tied dispute");
        require(witnessesVoteStatus[_disputeId][msg.sender] == VoteStatus.Default, "Duplicate voting is not allowed");

        address[] memory attWits = dispute.attWit;
        if ( _supportsRuling ) {
            dispute.status = DisputeStatus.Supported;
            IZeronV1Payments(dispute.zeronPaymentAddr).resolveDispute(dispute.plaintiff);
        } else {
            dispute.status = DisputeStatus.Opposited;
            IZeronV1Payments(dispute.zeronPaymentAddr).resolveDispute(dispute.defendant);
        }

        for(uint i=0; i<attWits.length; i++) {
            if ( witnessesVoteStatus[_disputeId][attWits[i]] == VoteStatus.Support && dispute.status == DisputeStatus.Supported || witnessesVoteStatus[_disputeId][attWits[i]] == VoteStatus.Opposition && dispute.status == DisputeStatus.Opposited ) {
                witnesses[attWits[i]].winCount++;
            } else {
                witnesses[attWits[i]].lossCount++;
            }
        }
    }


    function claimAttendanceRewards(bytes32 _disputeId) external unLock {
        Dispute storage dispute = disputes[_disputeId];
        require(witnessesVoteStatus[_disputeId][msg.sender] != VoteStatus.Default && witnessesVoteStatus[_disputeId][msg.sender] != VoteStatus.Claimed);
        require(dispute.status == DisputeStatus.Supported || dispute.status == DisputeStatus.Opposited);
        
        uint totalAttendanceRewardsAmount = dispute.amount * dispute.fee / 100;
        if ( dispute.status == DisputeStatus.Supported && witnessesVoteStatus[_disputeId][msg.sender] == VoteStatus.Support ) {
            uint eachAttendanceRewardsAmount = totalAttendanceRewardsAmount / dispute.voteCounter.inSupport;
            attendanceRewards[dispute.commisionTokenAddr][msg.sender] = attendanceRewards[dispute.commisionTokenAddr][msg.sender] + eachAttendanceRewardsAmount * witnesses[msg.sender].votingShares;
            witnessesVoteStatus[_disputeId][msg.sender] = VoteStatus.Claimed;
        } else {
            if ( dispute.status == DisputeStatus.Opposited && witnessesVoteStatus[_disputeId][msg.sender] == VoteStatus.Opposition ) {
                uint eachAttendanceRewardsAmount = totalAttendanceRewardsAmount / dispute.voteCounter.inOpposition;
                attendanceRewards[dispute.commisionTokenAddr][msg.sender] = attendanceRewards[dispute.commisionTokenAddr][msg.sender] + eachAttendanceRewardsAmount * witnesses[msg.sender].votingShares;
                witnessesVoteStatus[_disputeId][msg.sender] = VoteStatus.Claimed;
            }
        }
    }


    function withdrawAttendanceRewards(address tokenAddress, uint256 amount) external unLock onlyWitness {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        require(attendanceRewards[tokenAddress][msg.sender] >= amount, "Insufficient balance");

        attendanceRewards[tokenAddress][msg.sender] = attendanceRewards[tokenAddress][msg.sender] - amount;
        token.transfer(msg.sender, amount);
    }


    function getDetailOfDispute(bytes32 _disputeId) external view returns (Dispute memory) {
        return disputes[_disputeId];
    }


    function addWitnesses(address[] memory whitelist, uint256 amount) external onlyOwner {
        require(amount >= minStake * whitelist.length, "The staked amount is insufficient");
        require(IERC20(zntToken).transferFrom(msg.sender, address(this), amount), "Insufficient ZNT balance or approval");
        uint stakingAmount = amount / whitelist.length;
        for(uint i=0; i<whitelist.length; i++) {
            if (witnesses[whitelist[i]].isWitness) {
                continue;
            }
            witnesses[whitelist[i]].witnessAddr = msg.sender;
            witnesses[whitelist[i]].isWitness = true;
            witnesses[whitelist[i]].isArbitrator = false;
            witnesses[whitelist[i]].joinedAt = block.timestamp;
            witnesses[whitelist[i]].stakingAmount = stakingAmount;
            witnesses[whitelist[i]].votingShares = stakingAmount / minStake;
            witnesses[whitelist[i]].minStakingAmount = minStake; 
        }
    }


    function setArbitralState(bool _isUnLock) external onlyOwner {
        unLocked = _isUnLock;
    }


    function withdrawTokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        token.transfer(msg.sender, amount);
    }
}
