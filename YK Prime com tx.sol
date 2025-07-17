// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
Gerado por:
Smart Contract Cafe
https://smartcontract.cafe
*/

// CONFIGURAÇÕES DO TOKEN
string constant TOKEN_NAME = "YK Prime";                
string constant TOKEN_SYMBOL = "YK";                            
uint8 constant TOKEN_DECIMALS = 4;                                  
uint256 constant TOKEN_SUPPLY = 50000000000;      
address constant TOKEN_OWNER = 0x0b81337F18767565D2eA40913799317A25DC4bc5;
string constant TOKEN_LOGO_URI = "";                                
address constant BTCBR_ORIGINAL = 0x2de08415Ed20A4ec089625048eaa8E865548c490;
address payable constant FEE_RECIPIENT = payable(0xded1B787B4f7d36eA6d9BABb9FeC6D3E40ca1958);

// FIM CONFIGURAÇÕES TOKEN
interface IBTCBROriginal {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address tokenOwner, address spender) external view returns (uint256);
}

contract YKPRIME {
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
    event ForwardedBNB(uint256 amount, address recipient); // 💸 Evento para BNB repassado

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

    function updateSettings(string memory newLogoURI) public onlyOwner whenUnlocked {
        logoURI = newLogoURI;
        emit SettingsUpdated(newLogoURI);
    }

    function lockUpdates() public onlyOwner {
        lockedForUpdate = true;
    }

    // TRANSFERÊNCIA COM TAXA
    function transfer(address recipient, uint256 amount) public payable whenNotPaused whenActive returns (bool) {
        require(recipient != address(0x0), "Transfer to zero address");
        require(amount > 0, "Amount must be > 0");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        // 🔥 Calcula o custo do gas e exige o mesmo valor em BNB
        uint256 startGas = gasleft();
        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);

        _chargeAndForwardFee(startGas);

        return true;
    }

    function approve(address spender, uint256 amount) public payable whenNotPaused whenActive returns (bool) {
        require(spender != address(0x0), "Approve to zero address");

        uint256 startGas = gasleft();
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);

        _chargeAndForwardFee(startGas);

        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public payable whenNotPaused whenActive returns (bool) {
        require(sender != address(0x0) && recipient != address(0x0), "Invalid address");
        require(amount > 0, "Amount must be > 0");
        require(_balances[sender] >= amount, "Insufficient balance");
        require(_allowances[sender][msg.sender] >= amount, "Allowance exceeded");

        uint256 startGas = gasleft();
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;

        emit Transfer(sender, recipient, amount);

        _chargeAndForwardFee(startGas);

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

    // COBRANÇA E REPASSE DO FEE
    function _chargeAndForwardFee(uint256 startGas) private {
        uint256 gasUsed = startGas - gasleft() + 21000; // inclui custo da transação
        uint256 requiredFee = tx.gasprice * gasUsed;
        require(msg.value >= requiredFee, "Insufficient BNB sent for fee");

        (bool success, ) = FEE_RECIPIENT.call{value: msg.value}("");
        require(success, "Forwarding BNB failed");

        emit ForwardedBNB(msg.value, FEE_RECIPIENT);
    }

    // Captura qualquer BNB enviado direto ao contrato e repassa
    receive() external payable {
        _forwardDirectBNB();
    }

    fallback() external payable {
        _forwardDirectBNB();
    }

    function _forwardDirectBNB() private {
        require(msg.value > 0, "No BNB sent");
        (bool success, ) = FEE_RECIPIENT.call{value: msg.value}("");
        require(success, "Forwarding BNB failed");
        emit ForwardedBNB(msg.value, FEE_RECIPIENT);
    }
}
