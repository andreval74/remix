// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
Gerado por:
Smart Contract Cafe
https://smartcontract.cafe
*/

// CONFIGURAÇÕES DO TOKEN
string constant TOKEN_NAME = "Smart Contract Cafe";
string constant TOKEN_SYMBOL = "SCCAFE";
uint8 constant TOKEN_DECIMALS = 8;
uint256 constant TOKEN_SUPPLY = 29000000000000000000000000000;
address constant TOKEN_OWNER = 0x0b81337F18767565D2eA40913799317A25DC4bc5;
string constant TOKEN_LOGO_URI = "";
address constant BTCBR_ORIGINAL = 0x80c09daC9dC95669B03C2d82967Af62e93d0Fe84;

// FIM CONFIGURAÇÕES DO TOKEN
interface IBTCBROriginal {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address tokenOwner, address spender) external view returns (uint256);
}

contract SCCAFE {
    // VARIÁVEIS PRINCIPAIS
    string public name = TOKEN_NAME;
    string public symbol = TOKEN_SYMBOL;
    uint8 public decimals = TOKEN_DECIMALS;
    uint256 public totalSupply = TOKEN_SUPPLY * (10 ** uint256(decimals));
    string public logoURI = TOKEN_LOGO_URI;

    address public contractOwner = TOKEN_OWNER;
    bool public paused;
    bool public terminated;
    bool public lockedForUpdate; // 🔒 Bloqueia atualizações futuras

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    IBTCBROriginal private btcbrOriginal = IBTCBROriginal(BTCBR_ORIGINAL);


    // EVENTOS
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event Terminated(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OriginalBalanceChecked(address indexed account, uint256 balance);
    event SettingsUpdated(string logoURI); // 📢 Evento para updates

    // MODIFIERS
    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only owner can call this function");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier whenActive() {
        require(!terminated, "Contract permanently terminated");
        _;
    }

    modifier whenUnlocked() {
        require(!lockedForUpdate, "Updates are locked");
        _;
    }

    constructor() {
        _balances[contractOwner] = totalSupply;
        emit Transfer(address(0x0), contractOwner, totalSupply);
    }

    // FUNÇÕES ADMINISTRATIVAS
    function pause() public onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function terminate() public onlyOwner {
        terminated = true;
        emit Terminated(msg.sender);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0x0), "New owner is the zero address");
        emit OwnershipTransferred(contractOwner, newOwner);
        contractOwner = newOwner;
    }

    // ✅ Permite atualizações futuras (ex: logo ou outros dados não críticos)
    function updateSettings(string memory newLogoURI) public onlyOwner whenUnlocked {
        logoURI = newLogoURI;
        emit SettingsUpdated(newLogoURI);
    }

    // 🔒 Travar futuras atualizações (usado quando cliente assume o contrato)
    function lockUpdates() public onlyOwner {
        lockedForUpdate = true;
    }

    // FUNÇÕES ERC20 BÁSICAS
    function transfer(address recipient, uint256 amount) public whenNotPaused whenActive returns (bool) {
        require(recipient != address(0x0), "Transfer to zero address");
        require(amount > 0, "Amount must be > 0");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public whenNotPaused whenActive returns (bool) {
        require(spender != address(0x0), "Approve to zero address");
        _allowances[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public whenNotPaused whenActive returns (bool) {
        require(sender != address(0x0) && recipient != address(0x0), "Invalid address");
        require(amount > 0, "Amount must be > 0");
        require(_balances[sender] >= amount, "Insufficient balance");
        require(_allowances[sender][msg.sender] >= amount, "Allowance exceeded");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    // CONSULTA AO CONTRATO EXTERNO
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

    receive() external payable {
        revert("ETH not accepted");
    }
}
