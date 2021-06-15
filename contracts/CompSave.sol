// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Ownable.sol";
import "./CTokenInterface.sol";

contract CompSave is Ownable, ERC20("MToken", "MTK") { // native token
    
    IERC20 immutable DAI;
    CTokenInterface immutable cDAI;
    
    mapping (address => uint256) cExchangeRate;
    
    //kovan DAI -> 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa
    //kovan cDAI -> 0xf0d0eb522cfa50b716b3b1604c4f0fa6f04376ad

    constructor (address _DAI, address _cDAI) {
        require(_DAI != address(0) && _cDAI != address(0), "compsave: zero token address");
        DAI = IERC20(_DAI);
        cDAI = CTokenInterface(_cDAI);
    }

    /**
     * @notice Deposit DAI into contract
     * @dev Transfers DAI from user to contract and 
     *  mints native tokens (MTK) to user.
     * @param _amount Scaled (1e18) amount of DAI.
     */
    function deposit(uint256 _amount) external {
        require(balanceOf(msg.sender) == 0, "deposit: withdraw existing yield");
        require(DAI.transferFrom(msg.sender, address(this), _amount), "deposit: transfer failed");
        
        _mint(msg.sender, _amount); // mints MTK
        cExchangeRate[msg.sender] = cDAI.exchangeRateStored();
    }

    /**
     * @notice Deposit tokens to Compound & mint cTokens.
     * @dev onlyOwner can call this function periodically.
     * NOTE: Compound Interface returns 0 for no error.
     */
    function startSaving() public onlyOwner {
        uint256 daiBalance = DAI.balanceOf(address(this));
        DAI.approve(address(cDAI), daiBalance);
        require(cDAI.mint(daiBalance) == 0, "startSaving: cDAI mint failed"); // 0 => NO_ERROR
    }
    
    /**
     * @notice Withdraw yield for user
     * @dev calculates token amount from current cToken holdings,
     * and tranfer entire yield in DAI to user.
     */
    function withdraw() external {
        
        uint256 tokenBalance = balanceOf(msg.sender); // MTK Balance
        require(tokenBalance > 0 && cExchangeRate[msg.sender] > 0, "withdraw: insufficient tokens deposited");
        
        uint256 cTokenAmount = tokenBalance / cExchangeRate[msg.sender];
        require(cDAI.balanceOf(address(this)) >= cTokenAmount, "withdraw: insufficient tokens minted");
        
        require(cDAI.redeem(cTokenAmount) == 0, "withdraw: cToken transfer failed"); // 0 => NO_ERROR
        
        uint256 exchangeRate = cDAI.exchangeRateStored();
        uint256 tokenReturned = cTokenAmount * exchangeRate;
        DAI.transfer(msg.sender, tokenReturned); // transfer yeild to user
        
        delete cExchangeRate[msg.sender];
        _burn(msg.sender, tokenBalance); // burn MTK Balance
        
    }
}

