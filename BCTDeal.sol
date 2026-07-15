// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./common/dataOwnable.sol";
import "./common/counters.sol";
import "./common/safeMath.sol";
import "./interfaces/IBitSwapV2Pair.sol";
import "./interfaces/IBCTPricePointData.sol";

interface IBCT {
    function totalSupply() external view returns (uint256);
    function superBeforeTokenTransfer(address from, address to, uint256 amount) external;
    function superAfterTokenTransfer(address from, address to, uint256 amount) external;
    function superTransfer(address sender, address recipient, uint256 amount) external;
}

contract BCTDeal is DataOwnable {
    using SafeMath  for uint;
    
    constructor(address[] memory _operater) DataOwnable(_operater) {}

    IBCT public bct;
    IBCTPricePointData public bctPricePointData;
    bool public limitBuyOpFlag;
    bool public limitTransferFlag;
    address pairAddress;
    uint transferRate;
    address sellTaxReceiver;
    uint sellTaxRate;
    uint sellTaxEwRate;
    function setConfig(
        IBCT _bct, IBCTPricePointData _bctPricePointData, 
        bool _limitBuyOpFlag, bool _limitTransferFlag, 
        address _pairAddress, 
        uint _transferRate,
        address _sellTaxReceiver, 
        uint _sellTaxRate, uint _sellTaxEwRate) public onlyOwner {
        bct = _bct;
        bctPricePointData = _bctPricePointData;
        limitBuyOpFlag = _limitBuyOpFlag;
        limitTransferFlag = _limitTransferFlag;
        pairAddress = _pairAddress;
        transferRate = _transferRate;
        sellTaxReceiver = _sellTaxReceiver;
        sellTaxRate = _sellTaxRate;
        sellTaxEwRate = _sellTaxEwRate;
    }

    mapping(address => bool) public whitelist;
    function setWhitelist(address[] memory _whitelist, bool _flag) public onlyOwner {
        for(uint i = 0; i < _whitelist.length; i++) {
            whitelist[_whitelist[i]] = _flag;
        }
    }

    address gkcAddress;
    address communityAddress;
    function setCarvesConfig(address _gkcAddress, address _communityAddress) public onlyOwner {
        gkcAddress = _gkcAddress;
        communityAddress = _communityAddress;
    }

    function beforeTokenTransfer(address from, address to, uint256 amount) public onlyOperater {
        bct.superBeforeTokenTransfer(from, to, amount);

        if(limitBuyOpFlag) {
            if(from == pairAddress && !whitelist[to]) {
                revert("Buy restricted for non-whitelist");
            }
        }
    }

    function afterTokenTransfer(address from, address to, uint256 amount) public onlyOperater {
        bct.superAfterTokenTransfer(from, to, amount);

        if(pairAddress != address(0)) {
            bctPricePointData.recordPricePoint();

            sellTaxEwRate = bctPricePointData.getSellTaxEwRate();
        }
    }

    using Counters for Counters.Counter;
    Counters.Counter private _sellTaxRecordId;
    struct SellTaxRecord {
        uint8 taxType; // 1:normal; 2:sell;
        address from;
        address to;
        uint value;
        uint actualValue;
        uint fee;
        uint feeEw;
        uint gkcRate;
        uint communityRate;
        uint destroyRate;
        uint time;
    }
    mapping(uint256 => SellTaxRecord) public sellTaxRecords;

    function transfer(address sender, address recipient, uint256 amount) public onlyOperater {
        if(pairAddress != address(0)) {
            bctPricePointData.recordPricePoint();

            sellTaxEwRate = bctPricePointData.getSellTaxEwRate();
        }

        if (recipient == pairAddress && !whitelist[sender]) {
            dealTax(sender, recipient, amount, 2);
        } else {
            if(limitTransferFlag) {
                if(!whitelist[sender] && !whitelist[recipient]) {
                    dealTax(sender, recipient, amount, 1);
                } else {
                    bct.superTransfer(sender, recipient, amount);
                }
            } else {
                bct.superTransfer(sender, recipient, amount);
            }
        }
        
        if(pairAddress != address(0)) {
            bctPricePointData.recordPricePoint();

            sellTaxEwRate = bctPricePointData.getSellTaxEwRate();
        }
    }

    function dealTax(address sender, address recipient, uint256 amount, uint8 taxType) private {
        uint fee = 0;
        uint feeEw = 0;

        if(taxType == 1) {
            fee = amount.mul(transferRate) / 100;
        } else {
            fee = amount.mul(sellTaxRate) / 100;
            
            if(sellTaxEwRate > 0) {
                feeEw = amount.mul(sellTaxEwRate) / 100;
            }
        }

        uint totalFee = fee.add(feeEw);
        uint bctTotalSupply = bct.totalSupply();
        uint gkcRate = 40;
        uint communityRate = 40;
        uint destroyRate = 20;
        if(bctTotalSupply <= 2000000 * 1e8) {
            gkcRate = 50;
            communityRate = 50;
            destroyRate = 0;
        }

        bct.superTransfer(sender, gkcAddress, totalFee.mul(gkcRate) / 100);
        bct.superTransfer(sender, communityAddress, totalFee.mul(communityRate) / 100);
        if(destroyRate > 0) {
            bct.superTransfer(sender, address(1), totalFee.mul(destroyRate) / 100);
        }

        uint256 amountAfterFee = amount - totalFee;
        bct.superTransfer(sender, recipient, amountAfterFee);
        
        _sellTaxRecordId.increment();
        uint256 recordId = _sellTaxRecordId.current();
        sellTaxRecords[recordId].taxType = taxType;
        sellTaxRecords[recordId].from = sender;
        sellTaxRecords[recordId].to = recipient;
        sellTaxRecords[recordId].value = amount;
        sellTaxRecords[recordId].actualValue = amountAfterFee;
        sellTaxRecords[recordId].fee = fee;
        sellTaxRecords[recordId].feeEw = feeEw;
        sellTaxRecords[recordId].gkcRate = gkcRate;
        sellTaxRecords[recordId].communityRate = communityRate;
        sellTaxRecords[recordId].destroyRate = destroyRate;
        sellTaxRecords[recordId].time = block.timestamp;
    }
    
}
