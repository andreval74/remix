// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * ======= OpenZeppelin Contracts (Embedded) =======
 * Inclui Context, Ownable, Pausable, ERC20 com _burn
 */

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract Pausable is Context {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    function pause() public virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function unpause() public virtual {
        require(_paused, "Pausable: not paused");
        _paused = false;
        emit Unpaused(_msgSender());
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }
}

contract ERC20 is Context {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 6; // 6 casas decimais
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        address sender = _msgSender();
        _transfer(sender, to, amount);
        return true;
    }

    function allowance(address owner_, address spender) public view virtual returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        address sender = _msgSender();
        _approve(sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        address spender = _msgSender();
        uint256 currentAllowance = allowance(from, spender);
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(from, spender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        // --- Regras personalizadas ---
        IFBCoin token = IFBCoin(address(this));
        require(!token.paused(), "Transfers are paused");
        require(!token.isBlacklisted(from) && !token.isBlacklisted(to), "Address blacklisted");

        if (!token.isExemptFromLimits(from)) {
            uint256 maxDaily = (token.totalSupply() * token.maxDailyTransferPercent()) / 10000;
            uint256 maxMonthly = (token.totalSupply() * token.maxMonthlyTransferPercent()) / 10000;
            require(amount <= maxDaily, "Exceeds daily limit");
            require(amount <= maxMonthly, "Exceeds monthly limit");
        }

        uint256 taxAmount = 0;
        if (token.taxSocialPercent() > 0 && !token.isExemptFromLimits(from)) {
            taxAmount = (amount * token.taxSocialPercent()) / 10000;

            uint256 toProjects = (taxAmount * token.taxSocialProjectsPercent()) / 10000;
            uint256 toOperations = taxAmount - toProjects;

            if (toProjects > 0) {
                _balances[token.taxSocialProjectsWallet()] += toProjects;
                emit Transfer(from, token.taxSocialProjectsWallet(), toProjects);
            }
            if (toOperations > 0) {
                _balances[token.taxSocialOperationsWallet()] += toOperations;
                emit Transfer(from, token.taxSocialOperationsWallet(), toOperations);
            }

            token.emitTaxSocialApplied(from, toProjects, toOperations);
        }

        uint256 amountAfterTax = amount - taxAmount;
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amountAfterTax;
        }

        emit Transfer(from, to, amountAfterTax);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal virtual {
        require(owner_ != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }
}

/*
 * ======= IFBCoin Contract =======
 * Token com taxas sociais, limites anti-whale, blacklist e KYC
 */
contract IFBCoin is ERC20, Ownable, Pausable {
    // --- Informações básicas do token ---
    uint256 private _initialSupply = 10_000_000_000 * (10 ** 6); // 10 bilhões com 6 decimais

    // --- Endereços de controle ---
    address public taxSocialProjectsWallet = 0xB4a045aF12A74e5BEb8Ff763f474B943cc2Cfa0a;
    address public taxSocialOperationsWallet = 0xB4a045aF12A74e5BEb8Ff763f474B943cc2Cfa0a;
    address public nextContract = address(0);

    // --- Configurações ---
    uint256 public taxSocialPercent = 50; // 0.5%
    uint256 public taxSocialProjectsPercent = 3000; // 30% da taxa social
    uint256 public taxSocialOperationsPercent = 2000; // 20% da taxa social
    uint256 public monthlyBurnPercent = 100; // 1%
    uint256 public maxDailyTransferPercent = 1000; // 10%
    uint256 public maxMonthlyTransferPercent = 2000; // 20%

    // --- Listas ---
    mapping(address => bool) public isExemptFromLimits;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public kycVerified;

    // --- Eventos ---
    event TaxSocialApplied(address indexed from, uint256 amountProjects, uint256 amountOperations);
    event TokensBurned(uint256 amount);
    event Migration(address indexed to, uint256 amount);

    constructor() ERC20("IFB Coin", "IFB") {
        _mint(_msgSender(), _initialSupply);
        isExemptFromLimits[_msgSender()] = true;
    }

    // --- Funções administrativas ---
    function emitTaxSocialApplied(address from, uint256 amountProjects, uint256 amountOperations) external {
        require(_msgSender() == address(this), "Only token can emit");
        emit TaxSocialApplied(from, amountProjects, amountOperations);
    }

    function setTaxWallets(address _projectsWallet, address _operationsWallet) public onlyOwner {
        taxSocialProjectsWallet = _projectsWallet;
        taxSocialOperationsWallet = _operationsWallet;
    }

    function setNextContract(address _nextContract) public onlyOwner {
        nextContract = _nextContract;
    }

    function setTaxSocialPercent(uint256 newPercent) public onlyOwner {
        taxSocialPercent = newPercent;
    }

    function setTaxSocialProjectsPercent(uint256 newPercent) public onlyOwner {
        taxSocialProjectsPercent = newPercent;
    }

    function setTaxSocialOperationsPercent(uint256 newPercent) public onlyOwner {
        taxSocialOperationsPercent = newPercent;
    }

    function setMonthlyBurnPercent(uint256 newPercent) public onlyOwner {
        monthlyBurnPercent = newPercent;
    }

    function setMaxDailyTransferPercent(uint256 newPercent) public onlyOwner {
        maxDailyTransferPercent = newPercent;
    }

    function setMaxMonthlyTransferPercent(uint256 newPercent) public onlyOwner {
        maxMonthlyTransferPercent = newPercent;
    }

    function setExemption(address account, bool exempt) public onlyOwner {
        isExemptFromLimits[account] = exempt;
    }

    function setBlacklist(address account, bool blacklisted) public onlyOwner {
        isBlacklisted[account] = blacklisted;
    }

    function setKycStatus(address account, bool verified) public onlyOwner {
        kycVerified[account] = verified;
    }

    function burnMonthly() public onlyOwner {
        uint256 burnAmount = (balanceOf(address(this)) * monthlyBurnPercent) / 10000;
        require(burnAmount > 0, "Nothing to burn");
        _burn(address(this), burnAmount);
        emit TokensBurned(burnAmount);
    }

    function migrateToNextContract() public onlyOwner {
        require(nextContract != address(0), "Next contract not set");
        uint256 contractBalance = balanceOf(address(this));
        _transfer(address(this), nextContract, contractBalance);
        emit Migration(nextContract, contractBalance);
    }
}
