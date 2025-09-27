// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IPriceSource.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Pair {
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function getReserves() external view returns (uint112, uint112, uint32);
}

/// @notice Uniswap V2 çifti üzerinden basit TWAP (price0) hesaplar.
/// Basitlik için tek yön: token0/token1 fiyatı. Güncelleme iki ölçüm arasındaki zaman penceresine göre yapılır.
contract UniV2TwapAdapter is IPriceSource, Ownable {
    IUniswapV2Pair public immutable pair;
    bool public immutable usePrice0; // true: price0, false: price1
    uint8 public immutable decimalsOut; // döneceği fiyatın ondalığı (örn 8, 18)

    uint256 public lastCumulative;
    uint32  public lastTimestamp;
    uint256 public lastPriceX128; // Q128.128 formatında ortalama fiyat (ham)
    uint256 public lastUpdated;   // unix

    event Updated(uint256 priceX128, uint32 elapsed);

    constructor(IUniswapV2Pair _pair, bool _usePrice0, uint8 _decimalsOut) {
        pair = _pair;
        usePrice0 = _usePrice0;
        decimalsOut = _decimalsOut;

        // init snapshot
        ( , , uint32 ts) = _pair.getReserves();
        lastTimestamp = ts == 0 ? uint32(block.timestamp) : ts;
        lastCumulative = _currentCumulative(_pair);
    }

    function update() external {
        uint256 currCumulative = _currentCumulative(pair);
        (, , uint32 ts) = pair.getReserves();
        uint32 nowTs = ts == 0 ? uint32(block.timestamp) : ts;
        uint32 elapsed = nowTs - lastTimestamp;
        require(elapsed > 0, "no elapsed");

        // TWAP (Q128.128)
        uint256 priceX128 = ( (currCumulative - lastCumulative) / elapsed ) << 112; // approx scale
        lastCumulative = currCumulative;
        lastTimestamp = nowTs;

        lastPriceX128 = priceX128;
        lastUpdated = block.timestamp;
        emit Updated(priceX128, elapsed);
    }

    function _currentCumulative(IUniswapV2Pair p) internal view returns (uint256) {
        if (usePrice0) {
            return p.price0CumulativeLast();
        } else {
            return p.price1CumulativeLast();
        }
    }

    /// @notice IPriceSource: Q128.128'i decimalsOut’a projekte edip döndürür.
    function read() external view returns (int256 price, uint8 decimals, uint256 updatedAt) {
        require(lastPriceX128 != 0, "not updated");
        // Basit ölçekleme: price ≈ lastPriceX128 / 2^112
        // Sonucu decimalsOut ondalığa çeviriyoruz.
        uint256 pRay = (lastPriceX128 >> 112); // kaba yaklaşım
        price = int256(pRay);
        decimals = decimalsOut;
        updatedAt = lastUpdated;
    }
}
