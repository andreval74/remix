// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title IFBCoin
 * @dev Contrato do token BEP-20 para o projeto IFB.
 * Este contrato é upgradeable (atualizável) usando o padrão UUPS.
 * Inclui funcionalidades de Pausa, Blacklist, Anti-Whale, Taxas, Staking,
 * Governança Simplificada e Compliance.
 */
contract IFBCoin is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {

    // ============================================================================
    // Váriaveis de Configuração do Contrato - PREENCHER NO DEPLOY / REMIX
    // ============================================================================

    // 1. Configurações Básicas do Token
    string public constant TOKEN_NAME = "IFB Coin";
    string public constant TOKEN_SYMBOL = "IFB";
    uint8 public constant TOKEN_DECIMALS = 6;
    uint256 private constant INITIAL_TOTAL_SUPPLY = 1_000_000_000 * (10**6); // 1 Bilhão de tokens com 6 decimais

    // 2. Configurações de Segurança (Anti-Whale)
    uint256 public INITIAL_MAX_DAILY_TRANSFER = 1_000_000 * (10**6);   // 1 milhão de tokens
    uint256 public INITIAL_MAX_MONTHLY_TRANSFER = 20_000_000 * (10**6); // 20 milhões de tokens
    // O deployer será isento dos limites inicialmente.

    // 3. Configurações Econômicas (Taxas e Staking)
    uint256 public INITIAL_BASE_FEE_PERCENT = 200;           // 2% (200 = 2.00%)
    uint256 public INITIAL_HIGH_VALUE_FEE_PERCENT = 500;     // 5% (500 = 5.00%)
    uint256 public INITIAL_HIGH_VALUE_FEE_THRESHOLD = 700_000 * (10**6); // 700.000 tokens
    address public INITIAL_FEE_WALLET;                      // Endereço para onde as taxas são enviadas. Definido como msg.sender no initialize.

    uint256 public INITIAL_APR_12_MONTHS = 600;              // APR para 12 meses de staking (6% = 600 pontos base)
    uint256 public INITIAL_APR_24_MONTHS = 800;              // APR para 24 meses de staking (8% = 800 pontos base)
    uint256 public INITIAL_EARLY_WITHDRAWAL_PENALTY = 3000;  // Penalidade de retirada antecipada (30% = 3000 pontos base)

    // 4. Configurações de Governança
    // Exemplo de lock de equipe: o endereço 0x0 terá seus tokens travados por 366 dias a partir do deploy.
    // teamTokenLockReleaseTime[address(0)] = block.timestamp + 366 days; // Removido para a inicialização dinâmica, será configurado pelo owner
    uint256 public INITIAL_TEAM_LOCK_DURATION_DAYS = 366; // Duração padrão do lock para membros da equipe em dias

    // ============================================================================
    // Variáveis de Estado (não precisam ser preenchidas diretamente, são manipuladas por funções)
    // ============================================================================
    // Blacklist
    mapping(address => bool) public isBlacklisted;

    // Anti-Whale
    uint256 public maxDailyTransfer;
    uint256 public maxMonthlyTransfer;
    mapping(address => bool) public isExemptFromLimits; // Contas de controle (fundação, etc.)
    mapping(address => uint256) private _dailyTransferred;
    mapping(address => uint256) private _monthlyTransferred;
    mapping(address => uint256) private _lastTransferDay;
    mapping(address => uint256) private _lastTransferMonth;

    // Taxas
    uint256 public baseFeePercent;
    uint256 public highValueFeePercent;
    uint256 public highValueFeeThreshold;
    address public feeWallet;

    // Staking
    struct Stake {
        uint256 amount;
        uint256 since;
        uint256 duration; // 12 ou 24 meses
    }
    mapping(address => Stake) public stakes;
    uint256 public apr12Months;
    uint256 public apr24Months;
    uint256 public earlyWithdrawalPenalty;

    // Governança Simplificada
    mapping(address => uint256) public specialVotingPower; // Para diretoria, ONGs, etc.

    // Tempo de Lock para a Equipe
    mapping(address => uint256) public teamTokenLockReleaseTime;

    // Compliance
    mapping(address => bool) public kycVerified;
    mapping(address => bool) public isSanctioned;

    // Eventos
    event AddressBlacklisted(address indexed account);
    event AddressUnblacklisted(address indexed account);
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Withdrawn(address indexed user, uint256 principal, uint256 reward);
    event PenalizedWithdraw(address indexed user, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init(TOKEN_NAME, TOKEN_SYMBOL);
        __ERC20Burnable_init();
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        // Inicialização com as variáveis de configuração
        _mint(msg.sender, INITIAL_TOTAL_SUPPLY); // O total supply inicial é cunhado para o deployer.

        maxDailyTransfer = INITIAL_MAX_DAILY_TRANSFER;
        maxMonthlyTransfer = INITIAL_MAX_MONTHLY_TRANSFER;
        isExemptFromLimits[msg.sender] = true; // O deployer é isento inicialmente

        baseFeePercent = INITIAL_BASE_FEE_PERCENT;
        highValueFeePercent = INITIAL_HIGH_VALUE_FEE_PERCENT;
        highValueFeeThreshold = INITIAL_HIGH_VALUE_FEE_THRESHOLD;
        feeWallet = msg.sender; // As taxas vão para o deployer inicialmente, pode ser alterado depois.

        apr12Months = INITIAL_APR_12_MONTHS;
        apr24Months = INITIAL_APR_24_MONTHS;
        earlyWithdrawalPenalty = INITIAL_EARLY_WITHDRAWAL_PENALTY;

        // Exemplo de lock de equipe: o deployer ou outros endereços podem ser configurados via setTeamLock.
        // Se houver um endereço específico para lock inicial, ele pode ser adicionado aqui:
        // teamTokenLockReleaseTime[YOUR_TEAM_MEMBER_ADDRESS] = block.timestamp + INITIAL_TEAM_LOCK_DURATION_DAYS * 1 days;
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20Upgradeable) {
        // Aplica todas as regras antes da transferência
        _beforeTokenTransfer(from, to, amount);
        super._update(from, to, amount);
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============================================================================
    // HOOK CENTRAL: _beforeTokenTransfer
    // ============================================================================
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {
        require(!paused(), "Pausable: token transfer while paused");

        // Regra 2: Segurança
        require(!isBlacklisted[from] && !isBlacklisted[to], "Address is blacklisted");
        
        // Regra 5: Compliance
        require(!isSanctioned[from] && !isSanctioned[to], "Address is under sanctions");

        // Não aplicar taxas, limites ou locks em mints (from == address(0)) ou burns (to == address(0))
        if (from == address(0) || to == address(0)) {
            return;
        }
        
        // Regra 4: Governança - Lock da Equipe
        if (teamTokenLockReleaseTime[from] > block.timestamp) {
            revert("Team tokens are locked");
        }

        // Regra 2: Segurança - Anti-Whale
        _checkAntiWhaleLimits(from, amount);

        // Regra 3: Economia - Cálculo de Taxas
        uint256 fee = _calculateFee(amount);
        if (fee > 0) {
            super._update(from, feeWallet, fee);
        }
    }

    function _calculateFee(uint256 amount) internal view returns (uint256) {
        if (amount >= highValueFeeThreshold) {
            return (amount * highValueFeePercent) / 10000;
        }
        return (amount * baseFeePercent) / 10000;
    }

    function _checkAntiWhaleLimits(address from, uint256 amount) internal {
        if (isExemptFromLimits[from]) {
            return; // Isento das regras
        }

        uint256 currentDay = block.timestamp / 1 days;
        uint256 currentMonth = block.timestamp / 30 days;

        // Reset diário
        if (_lastTransferDay[from] != currentDay) {
            _dailyTransferred[from] = 0;
            _lastTransferDay[from] = currentDay;
        }

        // Reset mensal
        if (_lastTransferMonth[from] != currentMonth) {
            _monthlyTransferred[from] = 0;
            _lastTransferMonth[from] = currentMonth;
        }
        
        require(_dailyTransferred[from] + amount <= maxDailyTransfer, "Exceeds daily transfer limit");
        require(_monthlyTransferred[from] + amount <= maxMonthlyTransfer, "Exceeds monthly transfer limit");

        _dailyTransferred[from] += amount;
        _monthlyTransferred[from] += amount;
    }

    // ============================================================================
    // FUNÇÕES DE STAKING (Regra 3)
    // ============================================================================
    function stake(uint256 amount, uint256 durationInMonths) public {
        require(durationInMonths == 12 || durationInMonths == 24, "Invalid staking duration");
        require(stakes[msg.sender].amount == 0, "Already staking");
        require(amount > 0, "Cannot stake 0");
        
        stakes[msg.sender] = Stake({
            amount: amount,
            since: block.timestamp,
            duration: durationInMonths == 12 ? 365 days : 730 days
        });

        _transfer(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount, durationInMonths);
    }

    function withdrawStake() public {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake found");

        uint256 principal = userStake.amount;
        uint256 reward = 0;

        if (block.timestamp >= userStake.since + userStake.duration) {
            // Contrato cumprido, paga recompensa
            uint256 apr = (userStake.duration == 365 days) ? apr12Months : apr24Months;
            reward = (principal * apr * (userStake.duration / 1 days)) / (365 * 10000);
            
            delete stakes[msg.sender];
            _transfer(address(this), msg.sender, principal + reward);
            emit Withdrawn(msg.sender, principal, reward);
        } else {
            // Cancelamento antecipado com deságio
            uint256 penalty = (principal * earlyWithdrawalPenalty) / 10000;
            uint256 amountToReturn = principal - penalty;

            delete stakes[msg.sender];
            _transfer(address(this), msg.sender, amountToReturn);
            emit PenalizedWithdraw(msg.sender, amountToReturn);
        }
    }

    // ============================================================================
    // FUNÇÕES DE GOVERNANÇA (Regra 4)
    // ============================================================================
    function getVotingPower(address account) public view returns (uint256) {
        // Se tiver poder especial (diretoria, etc.), usa ele.
        if (specialVotingPower[account] > 0) {
            uint256 baseVotes = specialVotingPower[account];
            if (balanceOf(account) >= 50_000_000 * (10**6)) { // 50 milhões de tokens
                return baseVotes + 1; // Poder especial + 1 voto de holder
            }
            return baseVotes;
        }
        
        // Regra para holders comuns
        if (balanceOf(account) >= 50_000_000 * (10**6)) {
            return 1;
        }

        return 0;
    }

    // ============================================================================
    // FUNÇÕES ADMINISTRATIVAS (Controladas pelo Owner/Multisig)
    // ============================================================================
    
    // Funções de Segurança
    function pause() public onlyOwner { _pause(); }
    function unpause() public onlyOwner { _unpause(); }
    function blacklist(address account) public onlyOwner { isBlacklisted[account] = true; emit AddressBlacklisted(account); }
    function unblacklist(address account) public onlyOwner { isBlacklisted[account] = false; emit AddressUnblacklisted(account); }
    function setAntiWhaleExemption(address account, bool exempt) public onlyOwner { isExemptFromLimits[account] = exempt; }
    function setMaxDailyTransfer(uint256 newLimit) public onlyOwner { maxDailyTransfer = newLimit; }
    function setMaxMonthlyTransfer(uint256 newLimit) public onlyOwner { maxMonthlyTransfer = newLimit; }

    // Funções Econômicas
    function setFeeWallet(address newWallet) public onlyOwner { feeWallet = newWallet; }
    function setFees(uint256 newBaseFee, uint256 newHighValueFee, uint256 newThreshold) public onlyOwner {
        baseFeePercent = newBaseFee;
        highValueFeePercent = newHighValueFee;
        highValueFeeThreshold = newThreshold;
    }
    function setStakingAPRs(uint256 newApr12Months, uint256 newApr24Months) public onlyOwner {
        apr12Months = newApr12Months;
        apr24Months = newApr24Months;
    }
    function setEarlyWithdrawalPenalty(uint256 newPenalty) public onlyOwner {
        earlyWithdrawalPenalty = newPenalty;
    }

    // Funções de Governança
    function setTeamLock(address member, uint256 releaseTimestamp) public onlyOwner { teamTokenLockReleaseTime[member] = releaseTimestamp; }
    function setSpecialVotingPower(address voter, uint256 power) public onlyOwner { specialVotingPower[voter] = power; }

    // Funções de Compliance
    function setKycStatus(address user, bool verified) public onlyOwner { kycVerified[user] = verified; }
    function setSanctionStatus(address user, bool sanctioned) public onlyOwner { isSanctioned[user] = sanctioned; }
    modifier onlyKYCed() { require(kycVerified[msg.sender], "KYC not verified"); _; }

    // Função de Mint Controlado
    function mint(address to, uint256 amount) public onlyOwner { _mint(to, amount); }

    // ERC20 e Decimais (Regra 1)
    function decimals() public pure override returns (uint8) { return TOKEN_DECIMALS; }
}