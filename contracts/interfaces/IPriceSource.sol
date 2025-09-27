// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Tüm fiyat kaynakları bu arayüzü uygular.
interface IPriceSource {
    /// @return price   fiyat (signed), örn: 123.45 USD → 123450000 (decimals=6 ise)
    /// @return decimals fiyatın ondalık hanesi
    /// @return lastUpdated unix timestamp
    function read() external view returns (int256 price, uint8 decimals, uint256 lastUpdated);
}
