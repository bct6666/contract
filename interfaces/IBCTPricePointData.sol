// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBCTPricePointData {

    struct PricePoint {
        uint reserve0;
        uint reserve1;
        uint time;
    }
    function getPricePoint(uint) external view returns(PricePoint memory);
    function addPricePoint(PricePoint memory) external;
    function recordPricePoint() external;

    function getPrice24hAgo() external view returns (PricePoint memory);
    function getDailyChangeRate() external view returns (int256);
    function getSellTaxEwRate() external view returns(uint);
}
