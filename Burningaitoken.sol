/**
 *Submitted for verification at BscScan.com on 2025-07-10
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BurningAIToken is IBEP20 {
    string private _name = "Burning AI Token";
    string private _symbol = "BAIT";
    uint8 private _decimals = 18;
    uint256 private _totalSupply = 100_000_000 * 10**18; // 100M BAIT
    uint256 private _finalCirculation = 10_000_000 * 10**18; // 10M BAIT
    uint256 private _burnRate = 150; // 1.5% annual burn (basis points)
    uint256 private _feeRate = 2;    // 0.2% transfer fee (2 / 1000)

    address private _owner;
    address public teamWallet = 0xA9BBA551b1569f29F381689b9C0559B37D27bAf2;
    uint256 public lastBurnTime;
    uint256 public totalBurned;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    constructor() {
        _owner = msg.sender;
        _balances[teamWallet] = _totalSupply;
        lastBurnTime = block.timestamp;
        emit Transfer(address(0), teamWallet, _totalSupply);
    }

    function getOwner() external view override returns (address) {
        return _owner;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(_allowances[sender][msg.sender] >= amount, "Insufficient allowance");
        _allowances[sender][msg.sender] -= amount;
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0) && recipient != address(0), "Invalid address");
        require(_balances[sender] >= amount, "Insufficient balance");

        uint256 fee = 0;

        // Apply fee only if neither sender nor recipient is the teamWallet
        if (sender != teamWallet && recipient != teamWallet) {
            fee = (amount * _feeRate) / 1000; // 0.2%
        }

        uint256 amountAfterFee = amount - fee;

        _balances[sender] -= amount;
        _balances[recipient] += amountAfterFee;

        if (fee > 0) {
            _balances[teamWallet] += fee;
            emit Transfer(sender, teamWallet, fee);
        }

        emit Transfer(sender, recipient, amountAfterFee);
    }

    // 🔥 Annual burn function (1.5% per year)
    function executeAnnualBurn() external {
        require(block.timestamp >= lastBurnTime + 365 days, "Burn only once per year");
        require(_totalSupply > _finalCirculation, "Final circulation reached");

        uint256 burnAmount = (_totalSupply * _burnRate) / 10000;

        if (_totalSupply - burnAmount < _finalCirculation) {
            burnAmount = _totalSupply - _finalCirculation;
        }

        require(_balances[teamWallet] >= burnAmount, "Insufficient team balance");

        _balances[teamWallet] -= burnAmount;
        _totalSupply -= burnAmount;
        totalBurned += burnAmount;
        lastBurnTime = block.timestamp;

        emit Transfer(teamWallet, address(0x000000000000000000000000000000000000dEaD), burnAmount);
    }

    function getNextBurnAmount() external view returns (uint256) {
        if (_totalSupply <= _finalCirculation) return 0;
        uint256 burnAmount = (_totalSupply * _burnRate) / 10000;
        if (_totalSupply - burnAmount < _finalCirculation) {
            burnAmount = _totalSupply - _finalCirculation;
        }
        return burnAmount;
    }

    function getNextBurnTime() external view returns (uint256) {
        return lastBurnTime + 365 days;
    }
}
