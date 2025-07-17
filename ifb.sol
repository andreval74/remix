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
 * @dev Token BEP-20 para o projeto IFB com mecanismos de Taxa Social, Queima e Governança.
 */
contract IFBCoin is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {

    /* ================================================================
       Configurações Básicas do Token
       ================================================================ */
    string public constant TOKEN_NAME = "IFB Coin";
    string public constant TOKEN_SYMBOL = "IFB";
    uint8 public constant TOKEN_DECIMALS = 6;
    uint256 private constant INITIAL_TOTAL_SUPPLY = 10_000_000_000 * (10**6);

    /* ================================================================
       Configurações Variáveis - Taxas, Queima e Anti-Whale
       ================================================================ */
    // Taxa Social (em pontos base)
    uint256 public taxSocialPercent = 50; // 0,5% do valor da transação
    uint256 public taxSocialProjectsPercent = 30; // 0,3% para projetos sociais
    uint256 public taxSocialOperationsPercent = 20; // 0,2% para operações do ecossistema
    address public taxSocialProjectsWallet; // Carteira para projetos sociais
    address public taxSocialOperationsWallet; // Carteira para operações

    // Queima Mensal e Extra
    uint256 public monthlyBurnPercent = 100; // 1% de queima mensal
    uint256 public extraBurnTriggerPercent = 1500; // Queima extra se o preço cair 15%

    // Limites Anti-Whale
    uint256 public maxDailyTransferPercent = 1_000; // 10% do supply total por dia
    uint256 public maxMonthlyTransferPercent = 20_000; // 20% do supply total por mês
    mapping(address => bool) public isExemptFromLimits; // Endereços isentos

    /* ================================================================
       Governança e Compliance
       ================================================================ */
    uint256 public quorumPercent = 500; // Quorum mínimo de 5% para propostas DAO
    mapping(address => bool) public isBlacklisted; // Endereços bloqueados
    mapping(address => bool) public kycVerified;   // Endereços verificados via KYC

    /* ================================================================
       Eventos
       ================================================================ */
    event TaxSocialApplied(address indexed from, uint256 amountProjects, uint256 amountOperations);
    event TokensBurned(uint256 amount);
    event AddressBlacklisted(address indexed account);
    event AddressUnblacklisted(address indexed account);

    /* ================================================================
       Construtor e Inicialização
       ================================================================ */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _projectsWallet, address _operationsWallet) public initializer {
        __ERC20_init(TOKEN_NAME, TOKEN_SYMBOL);
        __ERC20Burnable_init();
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        _mint(msg.sender, INITIAL_TOTAL_SUPPLY);

        taxSocialProjectsWallet = _projectsWallet;
        taxSocialOperationsWallet = _operationsWallet;
        isExemptFromLimits[msg.sender] = true;
    }

    /* ================================================================
       Transferências - Hook para aplicar regras e taxas
       ================================================================ */
    function _update(address from, address to, uint256 amount) internal override {
        _beforeTokenTransfer(from, to, amount);
        super._update(from, to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {
        // Pausa do contrato
        require(!paused(), "Token transfer while paused");

        // Blacklist
        require(!isBlacklisted[from] && !isBlacklisted[to], "Address is blacklisted");

        // Anti-Whale (aplica limites de transferência)
        if (!isExemptFromLimits[from]) {
            uint256 maxDaily = (totalSupply() * maxDailyTransferPercent) / 10000;
            uint256 maxMonthly = (totalSupply() * maxMonthlyTransferPercent) / 10000;
            require(amount <= maxDaily, "Exceeds daily transfer limit");
            require(amount <= maxMonthly, "Exceeds monthly transfer limit");
        }

        // Taxa Social (dividida entre projetos e operações)
        uint256 taxAmount = (amount * taxSocialPercent) / 10000;
        if (taxAmount > 0) {
            uint256 toProjects = (taxAmount * taxSocialProjectsPercent) / taxSocialPercent;
            uint256 toOperations = taxAmount - toProjects;
            super._update(from, taxSocialProjectsWallet, toProjects);
            super._update(from, taxSocialOperationsWallet, toOperations);
            emit TaxSocialApplied(from, toProjects, toOperations);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /* ================================================================
       Funções Administrativas - Controle e Configurações
       ================================================================ */
    function pause() public onlyOwner { _pause(); }
    function unpause() public onlyOwner { _unpause(); }

    function blacklist(address account) public onlyOwner {
        isBlacklisted[account] = true;
        emit AddressBlacklisted(account);
    }

    function unblacklist(address account) public onlyOwner {
        isBlacklisted[account] = false;
        emit AddressUnblacklisted(account);
    }

    function setTaxSocialPercent(uint256 newPercent) public onlyOwner {
        require(newPercent <= 500, "Tax too high");
        taxSocialPercent = newPercent;
    }

    function setMonthlyBurnPercent(uint256 newPercent) public onlyOwner {
        monthlyBurnPercent = newPercent;
    }

    function burnMonthly() public onlyOwner {
        uint256 burnAmount = (balanceOf(address(this)) * monthlyBurnPercent) / 10000;
        _burn(address(this), burnAmount);
        emit TokensBurned(burnAmount);
    }

    function setExemption(address account, bool exempt) public onlyOwner {
        isExemptFromLimits[account] = exempt;
    }

    function setKycStatus(address account, bool verified) public onlyOwner {
        kycVerified[account] = verified;
    }
}
