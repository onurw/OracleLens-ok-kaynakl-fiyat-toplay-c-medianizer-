// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IPriceSource.sol";

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);
  function latestRoundData() external view returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  );
}

/// @notice Chainlink feed'i IPriceSource'a sarar.
contract ChainlinkAdapter is IPriceSource {
    AggregatorV3Interface public immutable feed;

    constructor(AggregatorV3Interface _feed) {
        feed = _feed;
    }

    function read() external view returns (int256, uint8, uint256) {
        (, int256 answer, , uint256 updatedAt, ) = feed.latestRoundData();
        return (answer, feed.decimals(), updatedAt);
    }
}
