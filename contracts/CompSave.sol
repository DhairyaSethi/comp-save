// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Ownable.sol";
import "./CTokenInterface.sol";

contract CompSave is Ownable {
    
    IERC20 immutable DAI;
    CTokenInterface immutable cDAI;
    
    mapping (address => uint256) cTokenAmount;
    mapping (address => uint256) tokenAmount;
    
    address[] public pendingDeposits;
    
    //kovan DAI -> 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa
    //kovan cDAI -> 0xf0d0eb522cfa50b716b3b1604c4f0fa6f04376ad

    constructor (address _DAI, address _cDAI) {
        DAI = IERC20(_DAI);
        cDAI = CTokenInterface(_cDAI);
    }
        
    // need to approve before hand
    function deposit(uint256 _amount) external {
        require(cTokenAmount[msg.sender] == 0, "deposit: withdraw existing yield");
        require(DAI.transferFrom(msg.sender, address(this), _amount), "deposit: transfer failed");
        
        tokenAmount[msg.sender] += _amount;
        pendingDeposits.push(msg.sender);
        
        //_mint(msg.sender, _amount);
    }
    
    function startSaving() public onlyOwner {
        for(uint i = pendingDeposits.length - 1; i >= 0; i --) {
            address who = pendingDeposits[i];
            uint256 amount = tokenAmount[who];
            if (amount > 0) {
                _mint(who, amount);
            }
            pendingDeposits.pop();
        }
    }
    
    function _mint(address _who, uint256 _amount) internal {
        DAI.approve(address(cDAI), _amount);
        cDAI.mint(_amount);
        
        uint256 exchangeRate = cDAI.exchangeRateCurrent();
        uint256 cDAIBalance = _amount / exchangeRate;
        cTokenAmount[_who] = cDAIBalance;
        
        delete tokenAmount[_who]; //resets to default value, ie 0
    }
    
    function withdraw() external {
        
        uint256 cDAIBalance = cTokenAmount[msg.sender];
        require(cDAIBalance > 0, "withdraw: insufficient tokens deposited");
        require(cDAI.balanceOf(address(this)) >= cDAIBalance, "withdraw: insufficient tokens minted");
        
        // uint256 exchangeRate = cDAI.exchangeRateCurrent();
        cDAI.redeem(cDAIBalance);
        uint256 exchangeRate = cDAI.exchangeRateStored();
        uint256 tokenReturned = cDAIBalance * exchangeRate;
        
        DAI.transfer(msg.sender, tokenReturned);
        
        delete cTokenAmount[msg.sender];
        
    }
    
    function getTokenAmount(address _who) public view returns(uint256) {
        return tokenAmount[_who];
    }
    
    
    function getcTokenAmount(address _who) public view returns(uint256) {
        return cTokenAmount[_who];
    }
}
