// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/*
  SFCoin
  Contrato ERC20 autônomo com:
  - Taxa social configurável e distribuição entre carteiras
  - Limites anti-whale (diário e mensal)
  - Carteiras especiais (principal, fundação/projects, admin/operations, holdings, gamificação)
  - Holding controlada: só o owner pode mover (deposit/withdraw), com lock/unlock
  - Pausável, blacklist, KYC, queima mensal e migração
  - Comentários por blocos para auditoria/entendimento
*/

contract SFCoin {
    /* 
     * 📝 VARIÁVEIS GERAIS / IDENTIDADE
     */
    string public constant name = "SFCoin";
    string public constant symbol = "SFC";
    uint8  public constant decimals = 7;
    uint256 public constant TOTAL_SUPPLY = 7_000_000_000 * (10 ** uint256(decimals));

    // Saldo e allowances (ERC20 padrão)
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Owner (admin) — configurável via constructor (padrão abaixo)
    address public owner;

    // Pausa global
    bool private _paused;

    // Contrato para migrar (next version)
    address public nextContract;

    // URL da logo (opcional)
    string public logoURL;

    /*
     * 🔹 CARTEIRAS ESPECIAIS (listas mutáveis)
     * - Todos os arrays permitem adicionar múltiplas carteiras
     */
    address[] public projectsWallets;    // Carteiras que recebem parcela "projects" da taxa social
    address[] public operationsWallets;  // Carteiras que recebem parcela "operations" da taxa social
    address[] public foundationWallets;  // (opcional) carteiras de fundação — podem ser usadas por você
    address[] public adminWallets;       // carteiras administrativas (taxas)
    address[] public holdingWallets;     // carteiras marcadas como holdings (cofres)
    address[] public gamificationWallets;// carteiras de gamificação/recompensas

    /*
     * 🔹 TAXAS, QUEIMA E LIMITES
     * Percentuais em base 10000 (i.e., 100 = 1%)
     */
    uint256 public taxSocialPercent = 50; // 50 = 0.5%
    uint256 public taxSocialProjectsPercent = 3000; // 30% da taxa social -> em base 10000 (i.e., 3000 => 30%)
    uint256 public taxSocialOperationsPercent = 2000; // 20% da taxa social

    uint256 public monthlyBurnPercent = 100; // 1% (base 10000)

    // Limites fixos (em unidades do token, já ajustadas pelo decimals)
    uint256 public constant MAX_DAILY_TRANSFER = 50_000 * (10 ** uint256(decimals));   // 50k / dia
    uint256 public constant MAX_MONTHLY_TRANSFER = 500_000 * (10 ** uint256(decimals)); // 500k / mês

    // Mapas de controle
    mapping(address => bool) public isExemptFromLimits; // endereços que não seguem limites
    mapping(address => bool) public isExemptFromTax;    // isenção de taxa social (se quiser)
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public kycVerified;
    mapping(address => bool) public holdingLocked; // locking per holding address

    /*
     * 🔹 CONTROLE DE LIMITES POR ENDEREÇO (diário/mensal)
     */
    struct TransferStats {
        uint256 dailyAmount;
        uint256 monthlyAmount;
        uint256 lastDay;   // day index (block.timestamp / 1 days)
        uint256 lastMonth; // month index (block.timestamp / 30 days)
    }
    mapping(address => TransferStats) private _transferStats;

    /*
     * 📢 EVENTOS
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);

    event TaxSocialApplied(address indexed from, uint256 amountProjects, uint256 amountOperations);
    event TokensBurned(uint256 amount);
    event Migration(address indexed to, uint256 amount);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event LogoURLUpdated(string oldURL, string newURL);

    event ProjectsWalletAdded(address wallet);
    event OperationsWalletAdded(address wallet);
    event FoundationWalletAdded(address wallet);
    event AdminWalletAdded(address wallet);
    event GamificationWalletAdded(address wallet);

    event HoldingAdded(address wallet);
    event HoldingRemoved(address wallet);
    event HoldingLocked(address wallet);
    event HoldingUnlocked(address wallet);

    /*
     * 🏗️ CONSTRUTOR
     * - Inicializa saldos, owner e carteiras iniciais conforme solicitado
     */
    constructor() {
        // Definir owner (endereço principal solicitado)
        owner = 0x130D2Ad33f3E5075e5552a7d3DEf5275Cb8baAEB;

        // Mint do total supply para o owner
        _balances[owner] = TOTAL_SUPPLY;
        emit Transfer(address(0), owner, TOTAL_SUPPLY);

        // Exceções
        isExemptFromLimits[owner] = true;
        isExemptFromTax[owner] = true;

        // Inicializar carteiras fornecidas
        projectsWallets.push(0x852202c54812aeD4e6A9FBD210Af2f6f61A5F7F7);   // inicial: fundação/projects
        operationsWallets.push(0x454ECE6E12E8e3616026d6438a61f9B0E09aAB7F); // inicial: admin/operations
        holdingWallets.push(0x4d2998F64966812b94E745f7A392Eae338f7bba3);    // initial holding
        gamificationWallets.push(0x9403438D29b3eb310c5a12D7c24deC0E57D69CF8); // gamificação

        emit OwnershipTransferred(address(0), owner);
    }

    /*
     * 👑 MODIFICADORES
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /*
     * 💸 ERC20 - FUNÇÕES PÚBLICAS
     */
    function totalSupply() public pure returns (uint256) {
        return TOTAL_SUPPLY;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public whenNotPaused returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "Transfer amount exceeds allowance");
        _approve(from, msg.sender, currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    /*
     * 🔒 ERC20 - FUNÇÕES INTERNAS
     * - _transfer aplica todas as regras: blacklist, holdings, limites, taxa
     */
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Transfer amount exceeds balance");
        require(!isBlacklisted[from] && !isBlacklisted[to], "Address blacklisted");

        // SE AQUI FOR UMA HOLDING (de ou para), só owner pode executar
        if (_isHoldingAddress(from) || _isHoldingAddress(to)) {
            require(msg.sender == owner, "Only owner can move holdings");
            // Além disso, se a holding estiver marcada como locked, bloqueia
            if (_isHoldingAddress(from)) {
                require(!holdingLocked[from], "Holding is locked (from)");
            }
            if (_isHoldingAddress(to)) {
                require(!holdingLocked[to], "Holding is locked (to)");
            }
        }

        // Limites anti-whale (aplicados somente se remetente NÃO for isExemptFromLimits e não for holding)
        if (!isExemptFromLimits[from] && !_isHoldingAddress(from)) {
            TransferStats storage stats = _transferStats[from];

            uint256 currentDay = block.timestamp / 1 days;
            uint256 currentMonth = block.timestamp / 30 days;

            if (stats.lastDay < currentDay) {
                stats.dailyAmount = 0;
                stats.lastDay = currentDay;
            }
            if (stats.lastMonth < currentMonth) {
                stats.monthlyAmount = 0;
                stats.lastMonth = currentMonth;
            }

            require(stats.dailyAmount + amount <= MAX_DAILY_TRANSFER, "Exceeds daily transfer limit");
            require(stats.monthlyAmount + amount <= MAX_MONTHLY_TRANSFER, "Exceeds monthly transfer limit");

            stats.dailyAmount += amount;
            stats.monthlyAmount += amount;
        }

        // Cálculo e distribuição da taxa social (se aplicável)
        uint256 taxAmount = 0;
        uint256 toProjects = 0;
        uint256 toOperations = 0;

        if (taxSocialPercent > 0 && !isExemptFromTax[from] && !isExemptFromTax[to]) {
            // taxAmount = amount * taxSocialPercent / 10000
            taxAmount = (amount * taxSocialPercent) / 10000;

            // distribuição
            toProjects = (taxAmount * taxSocialProjectsPercent) / 10000;
            toOperations = taxAmount - toProjects;

            // distribuir toProjects entre projectsWallets igualmente (se vazio, mantém no contrato)
            if (projectsWallets.length > 0 && toProjects > 0) {
                _distributeEven(projectsWallets, toProjects, from);
            } else if (toProjects > 0) {
                // credit to contract balance if no receiver configured
                _balances[address(this)] += toProjects;
                emit Transfer(from, address(this), toProjects);
            }

            // distribuir toOperations entre operationsWallets igualmente
            if (operationsWallets.length > 0 && toOperations > 0) {
                _distributeEven(operationsWallets, toOperations, from);
            } else if (toOperations > 0) {
                _balances[address(this)] += toOperations;
                emit Transfer(from, address(this), toOperations);
            }

            emit TaxSocialApplied(from, toProjects, toOperations);
        }

        // Transferência líquida
        uint256 amountAfterTax = amount - taxAmount;

        // Atualizar saldos
        _balances[from] -= amount;
        _balances[to] += amountAfterTax;
        emit Transfer(from, to, amountAfterTax);
    }

    // Função auxiliar para distribuir um valor total igualmente para os wallets no array
    function _distributeEven(address[] storage wallets, uint256 total, address payer) internal {
        uint256 len = wallets.length;
        if (len == 0) { return; }
        uint256 base = total / len;
        uint256 remainder = total - (base * len);

        for (uint256 i = 0; i < len; i++) {
            uint256 share = base;
            if (i == 0) { share += remainder; } // primeiro recebe eventual resto
            // creditar direto nos saldos
            _balances[wallets[i]] += share;
            emit Transfer(payer, wallets[i], share);
        }
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        require(owner_ != address(0) && spender != address(0), "Zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    /*
     * 🛠 FUNÇÕES ADMINISTRATIVAS (onlyOwner)
     * - Controle de owner, pausabilidade, ajuste de taxas, burn, migração, logo
     */

    // Transfer ownership (opcional)
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is zero");
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    // Pausa e unpause do contrato
    function pause() public onlyOwner {
        require(!_paused, "Already paused");
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner {
        require(_paused, "Not paused");
        _paused = false;
        emit Unpaused(msg.sender);
    }

    // Ajustes de taxas e parâmetros
    function setTaxSocialPercent(uint256 newPercent) external onlyOwner {
        require(newPercent <= 1000, "Tax too high (max 10%)");
        taxSocialPercent = newPercent;
    }

    function setTaxSocialDistribution(uint256 projectsPercent, uint256 operationsPercent) external onlyOwner {
        require(projectsPercent + operationsPercent <= 10000, "Invalid distribution");
        taxSocialProjectsPercent = projectsPercent;
        taxSocialOperationsPercent = operationsPercent;
    }

    function setMonthlyBurnPercent(uint256 newPercent) external onlyOwner {
        require(newPercent <= 1000, "Burn too high (max 10%)");
        monthlyBurnPercent = newPercent;
    }

    function setLogoURL(string memory newURL) external onlyOwner {
        emit LogoURLUpdated(logoURL, newURL);
        logoURL = newURL;
    }

    function setNextContract(address _next) external onlyOwner {
        nextContract = _next;
    }

    // Queima mensal dos tokens mantidos no contrato (chamar manualmente)
    function burnMonthly() external onlyOwner {
        uint256 contractBalance = _balances[address(this)];
        require(contractBalance > 0, "No contract balance");
        uint256 burnAmount = (contractBalance * monthlyBurnPercent) / 10000;
        require(burnAmount > 0, "Nothing to burn");
        _balances[address(this)] -= burnAmount;
        emit TokensBurned(burnAmount);
        emit Transfer(address(this), address(0), burnAmount);
    }

    // Migrar saldo do contrato para nextContract (owner chama)
    function migrateToNextContract() external onlyOwner {
        require(nextContract != address(0), "Next contract not set");
        uint256 contractBalance = _balances[address(this)];
        require(contractBalance > 0, "No balance to migrate");
        _balances[address(this)] -= contractBalance;
        _balances[nextContract] += contractBalance;
        emit Migration(nextContract, contractBalance);
        emit Transfer(address(this), nextContract, contractBalance);
    }

    /*
     * 🏦 FUNÇÕES DE HOLDING (apenas owner pode adicionar / mover)
     * - Holdings só movimentadas pelo owner (transfer e transferFrom bloqueiam)
     * - Owner pode usar depositToHolding / withdrawFromHolding para mover fundos
     */

    // Adicionar e remover holdings (listas)
    function addHolding(address wallet) external onlyOwner {
        require(wallet != address(0), "Zero address");
        holdingWallets.push(wallet);
        emit HoldingAdded(wallet);
    }

    function removeHolding(address wallet) external onlyOwner {
        require(wallet != address(0), "Zero address");
        // remover pela busca (mantém ordem; troca com último e pop)
        for (uint256 i = 0; i < holdingWallets.length; i++) {
            if (holdingWallets[i] == wallet) {
                holdingWallets[i] = holdingWallets[holdingWallets.length - 1];
                holdingWallets.pop();
                emit HoldingRemoved(wallet);
                return;
            }
        }
        revert("Holding not found");
    }

    // Lock / unlock holding
    function lockHolding(address wallet) external onlyOwner {
        holdingLocked[wallet] = true;
        emit HoldingLocked(wallet);
    }

    function unlockHolding(address wallet) external onlyOwner {
        holdingLocked[wallet] = false;
        emit HoldingUnlocked(wallet);
    }

    // Depositar para holding (owner somente)
    function depositToHolding(address holding, uint256 amount) external onlyOwner whenNotPaused {
        require(_isHoldingAddress(holding), "Not a holding");
        _transfer(owner, holding, amount); // owner chama -> permitido no _transfer
    }

    // Retirar de holding para owner (owner somente)
    function withdrawFromHolding(address holding, uint256 amount) external onlyOwner whenNotPaused {
        require(_isHoldingAddress(holding), "Not a holding");
        _transfer(holding, owner, amount); // owner chama -> permitido no _transfer
    }

    /*
     * 🔧 FUNÇÕES PARA CARTEIRAS ESPECIAIS (múltiplas)
     * - Adicionar / listar carteiras de projects (foundation), operations (admin),
     *   foundation, adminWallets e gamification
     */

    function addProjectsWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Zero address");
        projectsWallets.push(wallet);
        emit ProjectsWalletAdded(wallet);
    }

    function addOperationsWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Zero address");
        operationsWallets.push(wallet);
        emit OperationsWalletAdded(wallet);
    }

    function addFoundationWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Zero address");
        foundationWallets.push(wallet);
        emit FoundationWalletAdded(wallet);
    }

    function addAdminWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Zero address");
        adminWallets.push(wallet);
        emit AdminWalletAdded(wallet);
    }

    function addGamificationWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Zero address");
        gamificationWallets.push(wallet);
        emit GamificationWalletAdded(wallet);
    }

    // Getters para listas (públicos)
    function getProjectsWallets() external view returns (address[] memory) { return projectsWallets; }
    function getOperationsWallets() external view returns (address[] memory) { return operationsWallets; }
    function getFoundationWallets() external view returns (address[] memory) { return foundationWallets; }
    function getAdminWallets() external view returns (address[] memory) { return adminWallets; }
    function getHoldingWallets() external view returns (address[] memory) { return holdingWallets; }
    function getGamificationWallets() external view returns (address[] memory) { return gamificationWallets; }

    /*
     * ⚙️ CONTROLE (blacklist, exemptions, kyc)
     */
    function setExemption(address account, bool exempt) external onlyOwner {
        isExemptFromLimits[account] = exempt;
    }

    function setTaxExemption(address account, bool exempt) external onlyOwner {
        isExemptFromTax[account] = exempt;
    }

    function setBlacklist(address account, bool blacklisted) external onlyOwner {
        isBlacklisted[account] = blacklisted;
    }

    function setKycStatus(address account, bool verified) external onlyOwner {
        kycVerified[account] = verified;
    }

    /*
     * 🔍 UTILITÁRIAS / HELPERS
     */

    // Verifica se um endereço está marcado como holding
    function _isHoldingAddress(address wallet) internal view returns (bool) {
        for (uint256 i = 0; i < holdingWallets.length; i++) {
            if (holdingWallets[i] == wallet) { return true; }
        }
        return false;
    }

    // Recuperar allowance (padrão ERC20) - já implementado como função allowance()
    // Recuperar owner - já disponível

    /*
     * 🔁 FUNÇÕES PÚBLICAS ADICIONAIS (utilitárias)
     */

    // Recupera estatísticas de transferência de um endereço
    function getTransferStats(address account) external view returns (uint256 dailyAmount, uint256 monthlyAmount, uint256 lastDay, uint256 lastMonth) {
        TransferStats storage s = _transferStats[account];
        return (s.dailyAmount, s.monthlyAmount, s.lastDay, s.lastMonth);
    }

    /*
     * 🔁 APROVAÇÃO E TRANSFERÊNCIAS (helpers) - interfaces compatíveis ERC20
     */
    // Já temos approve, transfer e transferFrom públicos.
    // Fornecemos também increaseAllowance / decreaseAllowance padrões para UX:
    function increaseAllowance(address spender, uint256 addedValue) public whenNotPaused returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public whenNotPaused returns (bool) {
        uint256 current = _allowances[msg.sender][spender];
        require(current >= subtractedValue, "Decreased below zero");
        _approve(msg.sender, spender, current - subtractedValue);
        return true;
    }

    /*
     * 🧾 RESGATE DE FUNÇÕES DE EMERGÊNCIA (owner)
     */
    // Caso queira resgatar ERC20 acidental que chegue ao contrato, owner pode transferir
    function emergencyWithdrawToken(address token, uint256 amount) external onlyOwner {
        // Interface minimalista ERC20
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", owner, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Token transfer failed");
    }

    /*
     * Fallback / Receive
     * - contrato não espera receber BNB/ETH, mas aceita se necessário
     */
    receive() external payable { }
    fallback() external payable { }
}