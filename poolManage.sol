// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./common/dataOwnable.sol";
import "./common/counters.sol";
import "./common/safeMath.sol";
import "../common/IERC20.sol";
import "./interfaces/IBitSwapV2Pair.sol";
import "./interfaces/IBitSwapV2Router01.sol";

interface IBCT {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function mint(address, uint) external;
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function decimals() external view returns (uint8);

    function updBalanceOp(bool, address, uint) external;
    function updBalanceOp(address, address, uint) external;
    function totalSupplyOp(bool, uint) external;
}

contract PoolManage is DataOwnable {
    using SafeMath  for uint;
    
    constructor(address[] memory _operater) DataOwnable(_operater) {}

    struct Config {
        uint minSupplyNum;
        IBitSwapV2Router01 router;
        IBitSwapV2Pair bctUsdtPair;
        IBCT bctToken;

        address destroyTo;
        address sendTo;
    }
    Config public config;
    function setConfig(Config memory _config) public onlyOwner {
        config = _config;
    }

    // destroy and transfer / one hour exec
    struct DestroyAndSendRecord {
        string no;
        uint nDay;

        uint poolBctBalance;
        uint bctTotalSupply;

        uint destroyValue;
        uint destroyBase;
        uint destroyAmount;
        uint sendValue;
        uint sendBase;
        uint sendAmount;
        uint time;
        bool flag;
    }
    mapping(string => DestroyAndSendRecord) public destroyAndSendRecords;
    function destroyAndSendCheck(string memory _no) public view returns(uint) {
        if(destroyAndSendRecords[_no].flag) {
            return 1;
        }

        return 0;
    }

    function destroyAndSend(
        string memory _no,
        uint _nDay,
        uint _destroyValue,
        uint _destroyBase,
        uint _sendValue,
        uint _sendBase
    ) public onlyOperater {
        require(destroyAndSendCheck(_no) == 0, "check fail");

        uint poolBctBalance = config.bctToken.balanceOf(address(config.bctUsdtPair));
        uint bctTotalSupply = config.bctToken.totalSupply();

        uint destroyAmount = poolBctBalance.mul(_destroyValue) / _destroyBase;
        if(destroyAmount > 0 && bctTotalSupply > config.minSupplyNum) {
            if(bctTotalSupply - destroyAmount < config.minSupplyNum) {
                destroyAmount = bctTotalSupply - config.minSupplyNum;
            }
            
            config.bctToken.updBalanceOp(address(config.bctUsdtPair), config.destroyTo, destroyAmount);
            config.bctToken.totalSupplyOp(false, destroyAmount);
        }

        uint sendAmount = poolBctBalance.mul(_sendValue) / _sendBase;
        if(sendAmount > 0) {
            config.bctToken.updBalanceOp(address(config.bctUsdtPair), config.sendTo, sendAmount);
        }

        config.bctUsdtPair.sync();

        destroyAndSendRecords[_no] = DestroyAndSendRecord({
            no: _no,
            nDay: _nDay,
            poolBctBalance: poolBctBalance,
            bctTotalSupply: bctTotalSupply,

            destroyValue: _destroyValue,
            destroyBase: _destroyBase,
            destroyAmount: destroyAmount,

            sendValue: _sendValue,
            sendBase: _sendBase,
            sendAmount: sendAmount,

            time: block.timestamp,
            flag: true
        });
    }
    
}
