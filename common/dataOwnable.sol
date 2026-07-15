// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract DataOwnable {
    
    address public owner;
    address[] public operater;
    
    constructor(address[] memory _operater) {
        owner = msg.sender;
        operater = _operater;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier onlyOperater() {
        bool flag = false;
        if (msg.sender == owner)
            flag = true;
        else {
            for(uint256 i = 0; i < operater.length; i++) {
                if(msg.sender == operater[i] ) {
                    flag = true;
                    break;
                }
            }
        }

        require(flag);
        _;
    }

    function changeManager(address _owner, address[] memory _operater) 
        public onlyOwner returns(address) {
        if(_owner != address(0)) {
            owner = _owner;
        }
        
        if(_operater.length > 0) {
            operater = _operater;
        }
        
        return (owner);
    }
    
}