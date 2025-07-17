// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ===== OpenZeppelin Upgradeable Dependencies ===== */
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

    function _disableInitializers() internal virtual {
        _initialized = true;
    }
}

abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal {
        // REMOVIDO: onlyInitializing
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function __Ownable_init(address initialOwner) internal initializer {
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

    function _transferOwnership(address newOwner) internal virtual {
        _owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable {
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    function __ERC20_init(string memory name_, string memory symbol_) internal initializer {
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
        return 6; // IFB Token uses 6 decimals
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from zero");
        require(recipient != address(0), "ERC20: transfer to zero");

        uint256 senderBalance = balanceOf(sender);
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
        uint256 accountBalance = balanceOf(account);
        require(accountBalance >= amount, "ERC20: burn exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
    }
}

abstract contract UUPSUpgradeable is Initializable {
    function _authorizeUpgrade(address newImplementation) internal virtual;
}

contract IFBCoin is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {

    string public constant TOKEN_NAME = "IFB Coin";
    string public constant TOKEN_SYMBOL = "IFB";
    uint256 private constant INITIAL_TOTAL_SUPPLY = 10_000_000_000 * (10**6);

    uint256 public taxSocialPercent = 50;
    address public taxSocialProjectsWallet;
    address public taxSocialOperationsWallet;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _projectsWallet, address _operationsWallet) public initializer {
        __ERC20_init(TOKEN_NAME, TOKEN_SYMBOL);
        __Ownable_init(msg.sender);

        _mint(msg.sender, INITIAL_TOTAL_SUPPLY);

        taxSocialProjectsWallet = _projectsWallet;
        taxSocialOperationsWallet = _operationsWallet;
    }

    function burnMonthly() public onlyOwner {
        uint256 burnAmount = (balanceOf(address(this)) * taxSocialPercent) / 10000;
        _burn(address(this), burnAmount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}