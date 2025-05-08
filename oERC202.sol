// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title RebaseToken
 * @dev ERC20 Token with rebasing functionality
 */
contract RebaseToken is ERC20, Ownable {
    using SafeMath for uint256;

    // Rebase parameters
    uint256 private constant DECIMALS = 18;
    uint256 private constant MAX_SUPPLY = 100000000 * 10**DECIMALS; // 100 million tokens
    
    // Rebase state variables
    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    
    // Timestamp of last rebase
    uint256 public lastRebaseTime;
    
    // Rebase interval (1 day in seconds)
    uint256 public rebaseInterval = 86400;
    
    // Target price for the rebase (can be modified based on oracle input)
    uint256 public targetPrice = 1 * 10**DECIMALS;  // 1 USD in decimals
    
    // Current price (simulated, would be from oracle in production)
    uint256 public currentPrice = 1 * 10**DECIMALS;
    
    // Rebase percentage limit
    uint256 public maxRebasePercentage = 10; // 10% max change per rebase
    
    // Mapping from addresses to their gon balances
    mapping(address => uint256) private _gonBalances;
    
    // Mapping for allowances (in gons)
    mapping(address => mapping(address => uint256)) private _allowedGons;
    
    // Events
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event PriceUpdated(uint256 newPrice);
    event RebaseParametersUpdated(uint256 interval, uint256 maxPercentage);

    /**
     * @dev Constructor that initializes the token with name, symbol, and initial supply
     */
    constructor() ERC20("OoyeboahToken", "OOY") Ownable(msg.sender) {
        _totalSupply = 10000000 * 10**DECIMALS; // 10 million initial supply
        _gonsPerFragment = MAX_SUPPLY.div(_totalSupply);
        
        _gonBalances[msg.sender] = _totalSupply.mul(_gonsPerFragment);
        lastRebaseTime = block.timestamp;
        
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
    
    /**
     * @dev Returns the total supply of the token
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    /**
     * @dev Returns the balance of the specified address
     * @param account The address to query the balance of
     * @return The balance in fragments
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _gonBalances[account].div(_gonsPerFragment);
    }
    
    /**
     * @dev Transfer token for a specified address
     * @param to The address to transfer to
     * @param value The amount to be transferred
     * @return True if the transfer was successful
     */
    function transfer(address to, uint256 value) public override returns (bool) {
        uint256 gonValue = value.mul(_gonsPerFragment);
        _gonBalances[msg.sender] = _gonBalances[msg.sender].sub(gonValue);
        _gonBalances[to] = _gonBalances[to].add(gonValue);
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    /**
     * @dev Approve spender to spend tokens on behalf of owner
     * @param spender The address which will spend the funds
     * @param value The amount of tokens to be spent
     * @return True if the approval was successful
     */
    function approve(address spender, uint256 value) public override returns (bool) {
        _allowedGons[msg.sender][spender] = value.mul(_gonsPerFragment);
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    /**
     * @dev Transfer tokens from one address to another
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value The amount of tokens to be transferred
     * @return True if the transfer was successful
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        uint256 gonValue = value.mul(_gonsPerFragment);
        _allowedGons[from][msg.sender] = _allowedGons[from][msg.sender].sub(gonValue);
        _gonBalances[from] = _gonBalances[from].sub(gonValue);
        _gonBalances[to] = _gonBalances[to].add(gonValue);
        emit Transfer(from, to, value);
        return true;
    }
    
    /**
     * @dev Get the allowance for spender from owner
     * @param owner The address of the owner
     * @param spender The address of the spender
     * @return The amount of tokens allowed to be spent
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowedGons[owner][spender].div(_gonsPerFragment);
    }
    
    /**
     * @dev Increase the allowance of the spender
     * @param spender The address which will spend the funds
     * @param addedValue The amount of tokens to increase by
     * @return True if the increase was successful
     */
    function increaseAllowance(address spender, uint256 addedValue) public override returns (bool) {
        _allowedGons[msg.sender][spender] = 
            _allowedGons[msg.sender][spender].add(addedValue.mul(_gonsPerFragment));
        emit Approval(msg.sender, spender, allowance(msg.sender, spender));
        return true;
    }
    
    /**
     * @dev Decrease the allowance of the spender
     * @param spender The address which will spend the funds
     * @param subtractedValue The amount of tokens to decrease by
     * @return True if the decrease was successful
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public override returns (bool) {
        uint256 oldValue = _allowedGons[msg.sender][spender];
        if (subtractedValue.mul(_gonsPerFragment) >= oldValue) {
            _allowedGons[msg.sender][spender] = 0;
        } else {
            _allowedGons[msg.sender][spender] = 
                oldValue.sub(subtractedValue.mul(_gonsPerFragment));
        }
        emit Approval(msg.sender, spender, allowance(msg.sender, spender));
        return true;
    }
    
    /**
     * @dev Updates the current price (would use oracle in production)
     * @param newPrice The new price to set
     */
    function updatePrice(uint256 newPrice) external onlyOwner {
        currentPrice = newPrice;
        emit PriceUpdated(newPrice);
    }
    
    /**
     * @dev Updates rebase parameters
     * @param newInterval New rebase interval in seconds
     * @param newMaxPercentage New maximum rebase percentage
     */
    function setRebaseParameters(uint256 newInterval, uint256 newMaxPercentage) external onlyOwner {
        require(newInterval > 0, "Interval must be positive");
        require(newMaxPercentage > 0 && newMaxPercentage <= 50, "Invalid percentage");
        
        rebaseInterval = newInterval;
        maxRebasePercentage = newMaxPercentage;
        
        emit RebaseParametersUpdated(newInterval, newMaxPercentage);
    }
    
    /**
     * @dev Performs a rebase operation to adjust the total supply
     * Can only be triggered after rebaseInterval has passed since last rebase
     * @return The new total supply after rebase
     */
    function rebase() external onlyOwner returns (uint256) {
        require(block.timestamp >= lastRebaseTime.add(rebaseInterval), "Too early for rebase");
        
        // Calculate supply delta based on price deviation from target
        int256 supplyDelta = calculateSupplyDelta();
        
        // Apply the rebase
        if (supplyDelta == 0) {
            emit LogRebase(block.timestamp, _totalSupply);
            lastRebaseTime = block.timestamp;
            return _totalSupply;
        }
        
        if (supplyDelta < 0 && _totalSupply.add(uint256(-supplyDelta)) > MAX_SUPPLY) {
            supplyDelta = -int256(MAX_SUPPLY.sub(_totalSupply));
        }
        
        _totalSupply = supplyDelta >= 0
            ? _totalSupply.add(uint256(supplyDelta))
            : _totalSupply.sub(uint256(-supplyDelta));
            
        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }
        
        _gonsPerFragment = MAX_SUPPLY.div(_totalSupply);
        
        lastRebaseTime = block.timestamp;
        
        emit LogRebase(block.timestamp, _totalSupply);
        
        return _totalSupply;
    }
    
    /**
     * @dev Calculates the supply delta for rebasing based on price deviation
     * @return The supply delta (positive or negative)
     */
    function calculateSupplyDelta() private view returns (int256) {
        if (targetPrice == currentPrice) {
            return 0;
        }
        
        // Calculate the percentage deviation
        int256 deviation;
        if (currentPrice > targetPrice) {
            // Price is above target, need to increase supply (negative deviation)
            deviation = -int256(currentPrice.sub(targetPrice).mul(100).div(targetPrice));
        } else {
            // Price is below target, need to decrease supply (positive deviation)
            deviation = int256(targetPrice.sub(currentPrice).mul(100).div(targetPrice));
        }
        
        // Cap the deviation to the maximum rebase percentage
        if (deviation > int256(maxRebasePercentage)) {
            deviation = int256(maxRebasePercentage);
        } else if (deviation < -int256(maxRebasePercentage)) {
            deviation = -int256(maxRebasePercentage);
        }
        
        // Calculate the supply change
        return int256(_totalSupply) * deviation / 100;
    }
}
