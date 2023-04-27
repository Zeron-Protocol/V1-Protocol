// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ZeronToken is ERC20 {
    constructor() ERC20("Zeron Token", "ZNT") {
        _mint(msg.sender, 1000000000 * (10 ** 18));
    }
}
