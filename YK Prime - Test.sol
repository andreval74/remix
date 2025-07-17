// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
Gerado por:
Smart Contract Cafe
https://smartcontract.cafe
Com logs avançados para diagnóstico
*/

// ==============================
// CONFIGURAÇÕES DO TOKEN
// ==============================
string constant TOKEN_NAME = "WK TOKEN TST";
string constant TOKEN_SYMBOL = "WKTOKENTST";
uint8 constant TOKEN_DECIMALS = 4;
uint256 constant TOKEN_SUPPLY = 50000000000;
address constant TOKEN_OWNER = 0x0b81337F18767565D2eA40913799317A25DC4bc5;
string constant TOKEN_LOGO_URI = "";
address constant BTCBR_ORIGINAL = 0xBeeaF8eF890dF67F942C5E4697dC11cB83a3c43B;

contract WKTOKENTST {
    // ==============================
    // CONFIGURAÇÕES DA TAXA
    // A 'transactionFeePercent' agora representa o VALOR MÍNIMO em WEI de BNB
    // que deve ser pago como taxa.
    // Definido como 0 para que o usuário não precise adicionar BNB extra.
    // ==============================
    uint256 public transactionFeePercent = 0; // 🪙 Taxa inicial: 0 BNB (zero wei)
    address public feeRecipient = 0xB4a045aF12A74e5BEb8Ff763f474B943cc2Cfa0a; // 🏦 Carteira que recebe as taxas

    // ==============================
    // VARIÁVEIS PÚBLICAS
    // ==============================
    string public constant name = TOKEN_NAME;
    string public constant symbol = TOKEN_SYMBOL;
    uint8 public constant decimals = TOKEN_DECIMALS;
    uint256 public constant totalSupply = TOKEN_SUPPLY * (10 ** uint256(decimals));
    string public logoURI;

    address public contractOwner;
    bool public paused;
    bool public terminated;

    // ==============================
    // MAPEAMENTOS
    // ==============================
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ==============================
    // EVENTOS
    // ==============================
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event Terminated(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogoURIChanged(string newLogoURI);
    event FeeRecipientChanged(address newRecipient);
    event TransactionFeeChanged(uint256 newFeeAmount);
    event FeeCharged(address indexed from, uint256 feeAmountBNB);
    event DebugLog(string message, address addr, uint256 amount);

    // ==============================
    // MODIFICADORES
    // ==============================
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

    // ==============================
    // CONSTRUTOR
    // ==============================
    constructor() {
        contractOwner = TOKEN_OWNER;
        logoURI = TOKEN_LOGO_URI;
        _balances[contractOwner] = totalSupply;
        emit Transfer(address(0x0), contractOwner, totalSupply);
        emit DebugLog("Contract deployed", contractOwner, totalSupply);
    }

    // ==============================
    // FUNÇÕES ADMINISTRATIVAS
    // ==============================

    function setLogoURI(string memory newLogoURI) public onlyOwner {
        logoURI = newLogoURI;
        emit LogoURIChanged(newLogoURI);
    }

    function setFeeRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "Invalid fee recipient address");
        feeRecipient = newRecipient;
        emit FeeRecipientChanged(newRecipient);
    }

    // Função para definir o VALOR em WEI de BNB para a taxa
    // Permite que a taxa seja 0 ou qualquer valor positivo.
    function setTransactionFeePercent(uint256 newFeeAmount) public onlyOwner {
        require(newFeeAmount >= 0, "A taxa deve ser maior ou igual a zero");
        transactionFeePercent = newFeeAmount;
        emit TransactionFeeChanged(newFeeAmount);
    }

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

    // ==============================
    // FUNÇÕES ERC20 COM TAXA E LOGS
    // ==============================

    // Funções transfer e transferFrom são 'payable' para POSSIBILITAR receber BNB,
    // mas não o exigirão se transactionFeePercent for 0.
    function transfer(address recipient, uint256 amount) public payable whenNotPaused whenActive returns (bool) {
        emit DebugLog("Iniciando transferencia", msg.sender, amount);
        require(_balances[msg.sender] >= amount, "Saldo de token insuficiente");
        require(!isContract(recipient), "Destinatario e um contrato e pode rejeitar tokens");

        _collectFee(); // Cobra a taxa em BNB (se transactionFeePercent > 0)
        _transferTokens(msg.sender, recipient, amount); // Transfere o valor total de tokens

        emit DebugLog("Transferencia concluida", recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public whenNotPaused whenActive returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public payable whenNotPaused whenActive returns (bool) {
        emit DebugLog("Iniciando transferFrom", sender, amount);
        require(_allowances[sender][msg.sender] >= amount, "Permissao excedida");
        require(_balances[sender] >= amount, "Saldo de token insuficiente");
        require(!isContract(recipient), "Destinatario e um contrato e pode rejeitar tokens");

        _allowances[sender][msg.sender] -= amount;
        _collectFee(); // Cobra a taxa em BNB (se transactionFeePercent > 0)
        _transferTokens(sender, recipient, amount); // Transfere o valor total de tokens

        emit DebugLog("transferFrom concluida", recipient, amount);
        return true;
    }

    // Função interna para coletar a taxa em BNB
    function _collectFee() internal {
        // A taxa mínima esperada em BNB é 'transactionFeePercent'
        // Se transactionFeePercent for 0, msg.value pode ser 0.
        require(msg.value >= transactionFeePercent, "Valor insuficiente de BNB para a taxa");

        // Só transfere BNB se a taxa for maior que zero para evitar transações desnecessárias de 0 BNB
        if (transactionFeePercent > 0) {
            (bool success, ) = payable(feeRecipient).call{value: transactionFeePercent}("");
            require(success, "Falha na transferencia da taxa BNB para o recebedor");
            emit FeeCharged(msg.sender, transactionFeePercent);
            emit DebugLog("Taxa BNB cobrada", feeRecipient, transactionFeePercent);
        }
        
        // Se houver BNB extra enviado (msg.value > transactionFeePercent) e a taxa for > 0,
        // o excedente permanecerá no contrato.
        // Se a taxa for 0 e msg.value for > 0, o excedente também permanece no contrato.
        // Você pode adicionar uma lógica para devolver o excedente ao remetente aqui se desejar.
        // Exemplo para devolver:
        // if (msg.value > transactionFeePercent) {
        //     payable(msg.sender).transfer(msg.value - transactionFeePercent);
        // }
    }

    // Esta função transfere os tokens, sem dedução de taxa de token
    function _transferTokens(address from, address to, uint256 amount) internal {
        require(to != address(0x0), "Transferencia para endereco zero");
        require(amount > 0, "Valor deve ser maior que zero");

        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    // ==============================
    // CONSULTAS
    // ==============================

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    // Função 'receive' para ETH (BNB)
    receive() external payable {
        // Reverter se BNB for enviado diretamente SEM chamar transfer/transferFrom
        revert("Envie BNB apenas junto com uma transferencia de token para pagar a taxa.");
    }

    // ==============================
    // FUNÇÃO DE DETECÇÃO DE CONTRATO
    // ==============================
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}