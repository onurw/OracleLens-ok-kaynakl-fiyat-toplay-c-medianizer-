// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IPriceSource.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title OracleLensMedian
 * @notice Birden fazla IPriceSource'tan fiyat okur; staleness ve sapma kurallarıyla median döndürür.
 */
contract OracleLensMedian is Ownable, Pausable {
    struct Source {
        IPriceSource src;
        bool enabled;
    }

    Source[] public sources;
    uint256 public maxAge;          // saniye; bu süreden eski veriler geçersiz
    uint8   public outDecimals;     // normalize edilecek çıktı ondalığı (örn 8 veya 18)
    uint16  public maxDeviationBps; // median etrafı izinli sapma (örn 250 = %2.5)

    event SourceAdded(address src);
    event SourceToggled(uint256 index, bool enabled);
    event ConfigUpdated(uint256 maxAge, uint8 outDecimals, uint16 maxDeviationBps);

    constructor(uint256 _maxAge, uint8 _outDecimals, uint16 _maxDevBps) {
        maxAge = _maxAge;
        outDecimals = _outDecimals;
        maxDeviationBps = _maxDevBps; // 0 ise sapma kontrolü yok
    }

    function addSource(IPriceSource s) external onlyOwner {
        sources.push(Source({src: s, enabled: true}));
        emit SourceAdded(address(s));
    }

    function toggleSource(uint256 index, bool en) external onlyOwner {
        require(index < sources.length, "bad index");
        sources[index].enabled = en;
        emit SourceToggled(index, en);
    }

    function setConfig(uint256 _maxAge, uint8 _outDecimals, uint16 _maxDevBps) external onlyOwner {
        maxAge = _maxAge;
        outDecimals = _outDecimals;
        maxDeviationBps = _maxDevBps;
        emit ConfigUpdated(_maxAge, _outDecimals, _maxDevBps);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    /// @notice Aktif ve taze kaynaklardan median fiyatı döndürür.
    function readMedian() external view whenNotPaused returns (int256 price, uint8 decimals, uint256 updatedAt, uint256 usedCount) {
        require(sources.length > 0, "no sources");
        (int256[] memory ps, uint256[] memory ts, uint256 n) = _collect();
        require(n > 0, "no fresh");

        // sıralama için copy
        int256[] memory arr = new int256[](n);
        for (uint256 i = 0; i < n; i++) arr[i] = ps[i];
        _sort(arr);

        int256 med = arr[n/2]; // floor orta
        // sapma kontrolü (opsiyonel)
        if (maxDeviationBps > 0 && n > 2) {
            for (uint256 i = 0; i < n; i++) {
                int256 p = ps[i];
                int256 diff = p - med;
                if (diff < 0) diff = -diff;
                require(uint256(diff) * 10_000 <= uint256(_abs(med)) * maxDeviationBps, "deviation too high");
            }
        }

        // updatedAt = kullanılan kaynakların min(updatedAt)’i yerine median/avg de seçilebilirdi.
        // Burada en “eski” (min) zamanı döndürelim ki tüketiciler daha konservatif olsun.
        uint256 minTs = ts[0];
        for (uint256 i = 1; i < n; i++) if (ts[i] < minTs) minTs = ts[i];

        return (med, outDecimals, minTs, n);
    }

    function _collect() internal view returns (int256[] memory prices, uint256[] memory times, uint256 count) {
        prices = new int256[](sources.length);
        times  = new uint256[](sources.length);
        uint256 nowTs = block.timestamp;

        for (uint256 i = 0; i < sources.length; i++) {
            if (!sources[i].enabled) continue;
            (int256 p, uint8 d, uint256 t) = sources[i].src.read();
            if (p <= 0) continue; // negatif/0 fiyatı ele
            if (t == 0 || nowTs - t > maxAge) continue; // stale ele
            int256 norm = _normalize(p, d, outDecimals);
            prices[count] = norm;
            times[count]  = t;
            count++;
        }
    }

    function _normalize(int256 price, uint8 inDec, uint8 outDec) internal pure returns (int256) {
        if (inDec == outDec) return price;
        if (inDec < outDec) {
            return price * int256(10 ** (outDec - inDec));
        } else {
            return price / int256(10 ** (inDec - outDec));
        }
    }

    function _sort(int256[] memory a) internal pure {
        // insertion sort (n küçükken uygun)
        for (uint256 i = 1; i < a.length; i++) {
            int256 key = a[i];
            uint256 j = i;
            while (j > 0 && a[j-1] > key) {
                a[j] = a[j-1];
                j--;
            }
            a[j] = key;
        }
    }

    function _abs(int256 x) internal pure returns (int256) {
        return x >= 0 ? x : -x;
    }
}
