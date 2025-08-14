// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MultiTokenSale is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct TokenInfo {
        uint256 pricePerToken;   
        address tokenOwner;      
        bool exists;
        uint256 alertThreshold;  
    }

    mapping(address => TokenInfo) public tokens;
    uint256 public commissionBP; 
    address public commissionWallet; 

    event TokenAdded(address indexed token, uint256 pricePerToken, address indexed tokenOwner, uint256 alertThreshold);
    event TokenRemoved(address indexed token);
    event TokenPriceUpdated(address indexed token, uint256 newPrice);
    event TokenAlertThresholdUpdated(address indexed token, uint256 newThreshold);
    event CommissionUpdated(uint256 newBP, address newWallet);
    event TokensPurchased(address indexed buyer, address indexed token, uint256 amountPaid, uint256 tokensSent, uint256 commission);
    event TokenAlert(address indexed token, uint256 currentBalance);
    event BNBWithdrawn(uint256 amount);
    event TokensWithdrawn(address indexed token, uint256 amount);

    constructor(address _commissionWallet, uint256 _commissionBP) Ownable(msg.sender) {
        require(_commissionWallet != address(0), "Invalid commission wallet");
        require(_commissionBP <= 10000, "Max 100%");
        commissionWallet = _commissionWallet;
        commissionBP = _commissionBP;
    }

    function setCommission(uint256 _commissionBP, address _commissionWallet) external onlyOwner {
        require(_commissionBP <= 10000, "Max 100%");
        require(_commissionWallet != address(0), "Invalid wallet");
        commissionBP = _commissionBP;
        commissionWallet = _commissionWallet;
        emit CommissionUpdated(_commissionBP, _commissionWallet);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addToken(
        address tokenAddress,
        uint256 pricePerToken,
        address tokenOwner,
        uint256 alertThreshold
    ) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token");
        require(pricePerToken > 0, "Price > 0");
        require(tokenOwner != address(0), "Invalid token owner");

        tokens[tokenAddress] = TokenInfo(pricePerToken, tokenOwner, true, alertThreshold);
        emit TokenAdded(tokenAddress, pricePerToken, tokenOwner, alertThreshold);
    }

    function removeToken(address tokenAddress) external onlyOwner {
        require(tokens[tokenAddress].exists, "Token not registered");
        delete tokens[tokenAddress];
        emit TokenRemoved(tokenAddress);
    }

    function updatePrice(address tokenAddress, uint256 newPrice) external onlyOwner {
        require(tokens[tokenAddress].exists, "Token not registered");
        require(newPrice > 0, "Price > 0");
        tokens[tokenAddress].pricePerToken = newPrice;
        emit TokenPriceUpdated(tokenAddress, newPrice);
    }

    function updateAlertThreshold(address tokenAddress, uint256 newThreshold) external onlyOwner {
        require(tokens[tokenAddress].exists, "Token not registered");
        tokens[tokenAddress].alertThreshold = newThreshold;
        emit TokenAlertThresholdUpdated(tokenAddress, newThreshold);
    }

    function buyTokens(address tokenAddress, uint256 tokenAmount) external payable whenNotPaused nonReentrant {
        require(tokens[tokenAddress].exists, "Token not supported");
        require(tokenAmount > 0, "Amount > 0");

        TokenInfo memory info = tokens[tokenAddress];
        uint256 totalPrice = tokenAmount * info.pricePerToken;

        require(msg.value >= totalPrice, "Insufficient tBNB sent");

        uint256 commissionAmount = (totalPrice * commissionBP) / 10000;
        uint256 netAmount = totalPrice - commissionAmount;

        (bool sentCommission, ) = commissionWallet.call{value: commissionAmount}("");
        require(sentCommission, "Commission transfer failed");

        (bool sentOwner, ) = info.tokenOwner.call{value: netAmount}("");
        require(sentOwner, "Token owner transfer failed");

        IERC20 token = IERC20(tokenAddress);
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= tokenAmount, "Insufficient token balance in contract");

        token.safeTransfer(msg.sender, tokenAmount);

        if (contractBalance - tokenAmount <= info.alertThreshold) {
            emit TokenAlert(tokenAddress, contractBalance - tokenAmount);
        }

        emit TokensPurchased(msg.sender, tokenAddress, totalPrice, tokenAmount, commissionAmount);

        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    function withdrawBNB(uint256 amount) external onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(amount);
        emit BNBWithdrawn(amount);
    }

    function withdrawTokens(address tokenAddress, uint256 amount) external onlyOwner nonReentrant {
        IERC20 token = IERC20(tokenAddress);
        require(tokenAddress != address(0), "Invalid token address");
        token.safeTransfer(owner(), amount);
        emit TokensWithdrawn(tokenAddress, amount);
    }

    receive() external payable {}
}
