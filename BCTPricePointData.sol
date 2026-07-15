// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./common/dataOwnable.sol";
import "./interfaces/IBitSwapV2Pair.sol";
import "./interfaces/IBCTPricePointData.sol";

contract BCTPricePointData is DataOwnable, IBCTPricePointData {

    constructor(address[] memory _operater) DataOwnable(_operater) {}

    IBitSwapV2Pair public pair;
    address public bctToken;
    uint feeRate;
    function setConfig(IBitSwapV2Pair _pair, address _bctToken, uint _feeRate) public onlyOwner {
        pair = _pair;
        bctToken = _bctToken;
        feeRate = _feeRate;
    }

    PricePoint [] private pricePoints;
    function getPricePoint(uint _index) public override view returns(PricePoint memory) {
        return pricePoints[_index];
    }

    function addPricePoint(PricePoint memory _pricePoint) public override onlyOperater {
        pricePoints.push(_pricePoint);
    }

    function recordPricePoint() public override onlyOperater {
        // getReserve
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();

        // price not change
        if(pricePoints.length > 0) {
            PricePoint memory lastPricePoint = pricePoints[pricePoints.length - 1];
            if(lastPricePoint.reserve0 == reserve0 && lastPricePoint.reserve1 == reserve1) {
                return;
            }
        }

        addPricePoint(PricePoint({
            reserve0: reserve0, 
            reserve1: reserve1, 
            time: block.timestamp
        }));
    }

    function getPrice24hAgo() public override view returns (PricePoint memory) {
        uint256 targetTime = block.timestamp - 24 hours;
        uint256 len = pricePoints.length;
        
        if (pricePoints[0].time >= targetTime) {
            return pricePoints[0];
        }
        if (pricePoints[len - 1].time <= targetTime) {
            return pricePoints[len - 1];
        }
        
        uint256 left = 0;
        uint256 right = len - 1;
        uint256 beforeIndex = 0;
        
        while (left <= right) {
            uint256 mid = (left + right) / 2;
            if (pricePoints[mid].time <= targetTime) {
                beforeIndex = mid;
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        
        PricePoint memory before = pricePoints[beforeIndex];
        
        return before;
    }

    function quantityPrice(PricePoint memory _pricePoint) public view returns(uint) {
        uint reserve0 = _pricePoint.reserve0;
        uint reserve1 = _pricePoint.reserve1;
        if(pair.token0() == bctToken) {
            reserve0 = _pricePoint.reserve1;
            reserve1 = _pricePoint.reserve0;
        }

        return reserve0 * 1e18 / reserve1;
    }
    
    function getDailyChangeRate() public override view returns (int256) {
        PricePoint memory currentPricePoint = pricePoints[pricePoints.length - 1];
        PricePoint memory oldPricePoint = getPrice24hAgo();

        uint currentPrice = quantityPrice(currentPricePoint);
        uint oldPrice = quantityPrice(oldPricePoint);

        return (int256(currentPrice) - int256(oldPrice)) * 10000 / int256(oldPrice);
    }

    function getSellTaxEwRate() public override view returns(uint) {
        int256 rate24 = getDailyChangeRate();
        uint sellTaxEwRate = 0;
        if(rate24 < 0) {
            uint shareNum = uint(-rate24) / 1000;

            sellTaxEwRate = shareNum * 10;
        }

        if(sellTaxEwRate >= 30) {
            sellTaxEwRate = 30;
        }

        if(sellTaxEwRate > feeRate) {
            sellTaxEwRate -= feeRate;
        }

        return sellTaxEwRate;
    }
}
