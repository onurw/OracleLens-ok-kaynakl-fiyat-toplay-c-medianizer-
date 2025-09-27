// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IPriceSource.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Manuel güncellenen kaynak (acil durum/backup için).
contract ManualReporter is IPriceSource, Ownable {
    int256  private _price;
    uint8   private _decimals;
    uint256 private _updatedAt;

    event Reported(int256 price, uint8 decimals, uint256 updatedAt);

    constructor(int256 initialPrice, uint8 decimals_) {
        _price = initialPrice;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
    }

    function report(int256 price) external onlyOwner {
        _price = price;
        _updatedAt = block.timestamp;
        emit Reported(price, _decimals, _updatedAt);
    }

    function setDecimals(uint8 d) external onlyOwner { _decimals = d; }

    function read() external view returns (int256, uint8, uint256) {
        return (_price, _decimals, _updatedAt);
    }
}
