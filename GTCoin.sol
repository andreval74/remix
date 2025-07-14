// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
Gerado por:
Smart Contract Cafe
http://smartcontrat.cafe
https://x.com/smartccafe
*/

// CONFIGURAÇÕES DO TOKEN
string constant TOKEN_NAME = "GT Coin";
string constant TOKEN_SYMBOL = "GT";
uint8 constant TOKEN_DECIMALS = 4;
uint256 constant TOKEN_SUPPLY = 50000000000;
address constant TOKEN_OWNER = 0x0b81337F18767565D2eA40913799317A25DC4bc5;
string constant TOKEN_LOGO_URI = "https://gateway.pinata.cloud/ipfs/bafkreie5yoduwnobvjpz354kgwaylj5swiq2tx6zs4ptcm7465svl2huri";
address constant BTCBR_ORIGINAL = 0x8a57DE12f19ECb3d405cCc76B9B180505fF9d465;
// FIM DAS CONFIGURAÇÕES

interface IBTCBROriginal {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address tokenOwner, address spender) external view returns (uint256);
}

contract GTCoin {
    string public constant name = TOKEN_NAME;
    string public constant symbol = TOKEN_SYMBOL;
    uint8 public constant decimals = TOKEN_DECIMALS;
    uint256 public constant totalSupply = TOKEN_SUPPLY * (10 ** uint256(decimals));
    string public logoURI;

    address public contractOwner;
    bool public paused;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    IBTCBROriginal private btcbrOriginal = IBTCBROriginal(BTCBR_ORIGINAL);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OriginalBalanceChecked(address indexed account, uint256 balance);

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only owner can call this function");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        contractOwner = TOKEN_OWNER;
        logoURI = TOKEN_LOGO_URI;
        _balances[contractOwner] = totalSupply;
        emit Transfer(address(0), contractOwner, totalSupply);
    }

    function pause() public onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public whenNotPaused returns (bool) {
        require(recipient != address(0), "Transfer to zero address");
        require(_balances[msg.sender] >= amount, "Balance too low");
        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public whenNotPaused returns (bool) {
        require(spender != address(0), "Approve to zero address");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public whenNotPaused returns (bool) {
        require(sender != address(0) && recipient != address(0), "Invalid address");
        require(_balances[sender] >= amount, "Balance too low");
        require(_allowances[sender][msg.sender] >= amount, "Allowance too low");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function getOriginalName() public view returns (string memory) {
        return btcbrOriginal.name();
    }

    function getOriginalSymbol() public view returns (string memory) {
        return btcbrOriginal.symbol();
    }

    function getOriginalTotalSupply() public view returns (uint256) {
        return btcbrOriginal.totalSupply();
    }

    function getOriginalBalance(address account) public returns (uint256) {
        uint256 balance = btcbrOriginal.balanceOf(account);
        emit OriginalBalanceChecked(account, balance);
        return balance;
    }

    function getOriginalAllowance(address tokenOwner, address spender) public view returns (uint256) {
        return btcbrOriginal.allowance(tokenOwner, spender);
    }

    function getBalances(address account) public view returns (uint256 originalBalance, uint256 currentBalance) {
        return (btcbrOriginal.balanceOf(account), _balances[account]);
    }

    receive() external payable {
        revert("ETH not accepted");
    }
}
