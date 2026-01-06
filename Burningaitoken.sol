
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IPancakeRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address);
}

contract BurningAIToken is IBEP20 {
    // Token Information
    string public constant name = "Burning AI Token";
    string public constant symbol = "BAIT";
    uint8 public constant decimals = 18;
    
    // Supply Management
    uint256 private _totalSupply = 100_000_000 * 10**18; // 100 Million
    uint256 public constant FINAL_SUPPLY = 10_000_000 * 10**18; // 10 Million Final
    
    // Tax System (Max 3%)
    uint256 public buyTax = 0;   // 0%
    uint256 public sellTax = 3;  // 3%
    
    // Burn System
    uint256 public constant BURN_RATE = 150; // 1.5%
    uint256 public lastBurnTime;
    uint256 public totalBurned;
    
    // Wallets
    address public owner;
    address public constant TEAM_WALLET = 0x9e63784D6FfaC30e36a4D851D2192e7714f7722e;
    
    // PancakeSwap V2
    IPancakeRouter public constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public pair;
    
    // Mappings
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludedFromFee;
    
    // Events
    event TaxesUpdated(uint256 buyTax, uint256 sellTax);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ExcludedFromFee(address indexed account, bool status);
    event AutoBurnExecuted(uint256 amount, uint256 timestamp);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }
    
    // Constructor
    constructor() {
        owner = 0x4826Cf80f523CFE4B566E6e778adBA0926E8CfD9;
        
        // Initial supply to team wallet
        _balances[TEAM_WALLET] = _totalSupply;
        emit Transfer(address(0), TEAM_WALLET, _totalSupply);
        
        // Create PancakeSwap Pair
        pair = IPancakeFactory(ROUTER.factory()).createPair(address(this), ROUTER.WETH());
        
        // Set fee exemptions
        isExcludedFromFee[owner] = true;
        isExcludedFromFee[TEAM_WALLET] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[address(ROUTER)] = true;  // Important for adding liquidity
        isExcludedFromFee[pair] = true;             // Important for trading
        
        lastBurnTime = block.timestamp;
    }
    
    // ==================== BEP-20 Standard Functions ====================
    
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }
    
    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowances[owner_][spender];
    }
    
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "BEP20: transfer amount exceeds allowance");
        
        if (currentAllowance != type(uint256).max) {
            _approve(sender, msg.sender, currentAllowance - amount);
        }
        
        _transfer(sender, recipient, amount);
        return true;
    }
    
    // ==================== Internal Functions ====================
    
    function _approve(address owner_, address spender, uint256 amount) internal {
        require(owner_ != address(0), "BEP20: approve from zero address");
        require(spender != address(0), "BEP20: approve to zero address");
        
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "BEP20: transfer from zero address");
        require(recipient != address(0), "BEP20: transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(_balances[sender] >= amount, "BEP20: transfer amount exceeds balance");
        
        // 🔥 AUTO-BURN CHECK: Check and execute burn before every transfer
        _checkAndExecuteAutoBurn();
        
        // Calculate tax (if applicable)
        uint256 taxAmount = 0;
        
        if (!isExcludedFromFee[sender] && !isExcludedFromFee[recipient]) {
            if (sender == pair) {
                // Buy transaction
                taxAmount = (amount * buyTax) / 100;
            } else if (recipient == pair) {
                // Sell transaction
                taxAmount = (amount * sellTax) / 100;
            }
        }
        
        uint256 transferAmount = amount - taxAmount;
        
        // Update balances
        _balances[sender] -= amount;
        _balances[recipient] += transferAmount;
        
        // Send tax to team wallet
        if (taxAmount > 0) {
            _balances[TEAM_WALLET] += taxAmount;
            emit Transfer(sender, TEAM_WALLET, taxAmount);
        }
        
        emit Transfer(sender, recipient, transferAmount);
    }
    
    // ==================== AUTOMATIC ANNUAL BURN SYSTEM ====================
    
    function _checkAndExecuteAutoBurn() internal {
        // Check if 365 days have passed since last burn
        if (block.timestamp >= lastBurnTime + 365 days && _totalSupply > FINAL_SUPPLY) {
            
            uint256 burnAmount = (_totalSupply * BURN_RATE) / 10000; // 1.5%
            
            // Adjust if burn would go below final supply
            if (_totalSupply - burnAmount < FINAL_SUPPLY) {
                burnAmount = _totalSupply - FINAL_SUPPLY;
            }
            
            // Check team wallet balance
            if (_balances[TEAM_WALLET] >= burnAmount) {
                // Execute burn
                _balances[TEAM_WALLET] -= burnAmount;
                _totalSupply -= burnAmount;
                totalBurned += burnAmount;
                lastBurnTime = block.timestamp;
                
                emit Transfer(TEAM_WALLET, address(0x000000000000000000000000000000000000dEaD), burnAmount);
                emit AutoBurnExecuted(burnAmount, block.timestamp);
            }
        }
    }
    
    // ==================== View Functions ====================
    
    function getNextBurnAmount() external view returns (uint256) {
        if (_totalSupply <= FINAL_SUPPLY) return 0;
        uint256 burnAmount = (_totalSupply * BURN_RATE) / 10000;
        if (_totalSupply - burnAmount < FINAL_SUPPLY) {
            burnAmount = _totalSupply - FINAL_SUPPLY;
        }
        return burnAmount;
    }
    
    function getNextBurnTime() external view returns (uint256) {
        return lastBurnTime + 365 days;
    }
    
    function isBurnDue() external view returns (bool) {
        return (block.timestamp >= lastBurnTime + 365 days && _totalSupply > FINAL_SUPPLY);
    }
    
    // ==================== Owner Functions ====================
    
    function updateTaxes(uint256 newBuyTax, uint256 newSellTax) external onlyOwner {
        require(newBuyTax <= 0 && newSellTax <= 3, "Tax cannot exceed 3%");
        buyTax = newBuyTax;
        sellTax = newSellTax;
        emit TaxesUpdated(newBuyTax, newSellTax);
    }
    
    function excludeFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
        emit ExcludedFromFee(account, excluded);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        isExcludedFromFee[newOwner] = true;
    }
    
    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
    
    // ==================== Additional Safety ====================
    
    // Recover accidentally sent BNB
    function recoverBNB() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    // Recover accidentally sent BEP20 tokens
    function recoverBEP20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "Cannot recover own token");
        IBEP20(tokenAddress).transfer(owner, amount);
    }
}
