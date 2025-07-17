// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * OpenZeppelin Contracts (flattened for upgradeable)
 * All dependencies inlined for Remix compilation
 */

/* ========== Initializable.sol ========== */
abstract contract Initializable {
    bool private _initialized;
    bool private _initializing;

    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _disableInitializers() internal virtual {
        _initialized = true;
    }
}

/* ========== ContextUpgradeable.sol ========== */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {}

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/* ========== OwnableUpgradeable.sol ========== */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Context_init();
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/* ========== PausableUpgradeable.sol ========== */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    function __Pausable_init() internal onlyInitializing {
        __Context_init();
        _paused = false;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/* ========== ERC20Upgradeable.sol ========== */
abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __Context_init();
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
        return 6; // Custom decimals for IFB
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from zero");
        require(recipient != address(0), "ERC20: transfer to zero");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to zero");
        _totalSupply += amount;
        _balances[account] += amount;
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from zero");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from zero");
        require(spender != address(0), "ERC20: approve to zero");
        _allowances[owner][spender] = amount;
    }
}

/* ========== ERC20BurnableUpgradeable.sol ========== */
abstract contract ERC20BurnableUpgradeable is Initializable, ERC20Upgradeable {
    function __ERC20Burnable_init() internal onlyInitializing {}

    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
}

/* ========== UUPSUpgradeable.sol ========== */
abstract contract UUPSUpgradeable is Initializable {
    function _authorizeUpgrade(address newImplementation) internal virtual;
}

/* ========== IFBCoin.sol ========== */
contract IFBCoin is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {

    string public constant TOKEN_NAME = "IFB Coin";
    string public constant TOKEN_SYMBOL = "IFB";
    uint8 public constant TOKEN_DECIMALS = 6;
    uint256 private constant INITIAL_TOTAL_SUPPLY = 10_000_000_000 * (10**6);

    uint256 public taxSocialPercent = 50;
    uint256 public taxSocialProjectsPercent = 30;
    uint256 public taxSocialOperationsPercent = 20;
    address public taxSocialProjectsWallet;
    address public taxSocialOperationsWallet;

    uint256 public monthlyBurnPercent = 100;
    uint256 public extraBurnTriggerPercent = 1500;

    uint256 public maxDailyTransferPercent = 1_000;
    uint256 public maxMonthlyTransferPercent = 20_000;
    mapping(address => bool) public isExemptFromLimits;

    uint256 public quorumPercent = 500;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public kycVerified;

    event TaxSocialApplied(address indexed from, uint256 amountProjects, uint256 amountOperations);
    event TokensBurned(uint256 amount);
    event AddressBlacklisted(address indexed account);
    event AddressUnblacklisted(address indexed account);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _projectsWallet, address _operationsWallet) public initializer {
        __ERC20_init(TOKEN_NAME, TOKEN_SYMBOL);
        __ERC20Burnable_init();
        __Pausable_init();
        __Ownable_init(msg.sender);

        _mint(msg.sender, INITIAL_TOTAL_SUPPLY);

        taxSocialProjectsWallet = _projectsWallet;
        taxSocialOperationsWallet = _operationsWallet;
        isExemptFromLimits[msg.sender] = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        _beforeTokenTransfer(from, to, amount);
        super._transfer(from, to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {
        require(!paused(), "Token transfer while paused");
        require(!isBlacklisted[from] && !isBlacklisted[to], "Address is blacklisted");

        if (!isExemptFromLimits[from]) {
            uint256 maxDaily = (totalSupply() * maxDailyTransferPercent) / 10000;
            uint256 maxMonthly = (totalSupply() * maxMonthlyTransferPercent) / 10000;
            require(amount <= maxDaily, "Exceeds daily transfer limit");
            require(amount <= maxMonthly, "Exceeds monthly transfer limit");
        }

        uint256 taxAmount = (amount * taxSocialPercent) / 10000;
        if (taxAmount > 0) {
            uint256 toProjects = (taxAmount * taxSocialProjectsPercent) / taxSocialPercent;
            uint256 toOperations = taxAmount - toProjects;
            super._transfer(from, taxSocialProjectsWallet, toProjects);
            super._transfer(from, taxSocialOperationsWallet, toOperations);
            emit TaxSocialApplied(from, toProjects, toOperations);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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
