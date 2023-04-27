// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IZeronV1Router {
    event ArbitralChanged(address arbitral);
    event CommisionTokenChanged(address token, bool isSupport);
    event FeeChanged(uint256 fee);
    event OwnerChanged(address oldOwner, address newOwner);

    function arbitral() external view returns (address);

    function createZeronPayments(
        address _employee,
        uint256 _amount,
        string memory _task,
        uint256 _duration,
        address _commisionToken
    ) external returns (address);

    function getAllZeronPayments() external view returns (address[] memory);

    function getZeronPaymentsByEmployee(address _employee)
        external
        view
        returns (address[] memory);

    function getZeronPaymentsByEmployer(address _employer)
        external
        view
        returns (address[] memory);

    function owner() external view returns (address);

    function serviceFee() external view returns (uint24);

    function setArbitral(address _arbitral) external;

    function setCommisionToken(address _commisionToken, bool isSupport)
        external;

    function setFees(uint24 _fee) external;

    function setOwner(address _owner) external;

    function setRouterState(bool _isUnLock) external;

    function supportCommissionTokens(address) external view returns (bool);

    function unLocked() external view returns (bool);

    function withdrawTokens(address tokenAddress, uint256 amount) external;
}