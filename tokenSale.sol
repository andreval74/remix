// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenSale {
    address public owner;
    IERC20 public token;

    address public commissionWallet;
    address public tokenOwnerWallet;
    uint256 public tokenPrice; // em wei (tBNB)
    uint256 public commissionPercent; // Ex: 5 = 5%

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 totalCost);

    modifier onlyOwner() {
        require(msg.sender == owner, "Somente o dono pode executar");
        _;
    }

    constructor(
        address _tokenAddress,
        address _commissionWallet,
        address _tokenOwnerWallet,
        uint256 _tokenPrice,
        uint256 _commissionPercent
    ) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        commissionWallet = _commissionWallet;
        tokenOwnerWallet = _tokenOwnerWallet;
        tokenPrice = _tokenPrice;
        commissionPercent = _commissionPercent;
    }

    function buyTokens(uint256 tokenAmount) public payable {
        uint256 totalCost = tokenAmount * tokenPrice;
        require(msg.value == totalCost, "Valor incorreto enviado");

        uint256 commission = (msg.value * commissionPercent) / 100;
        uint256 remaining = msg.value - commission;

        require(payable(commissionWallet).send(commission), "Falha ao enviar comissao");
        require(payable(tokenOwnerWallet).send(remaining), "Falha ao enviar valor ao dono do token");

        require(token.balanceOf(address(this)) >= tokenAmount, "Tokens insuficientes no contrato");
        require(token.transfer(msg.sender, tokenAmount), "Falha ao transferir tokens");

        emit TokensPurchased(msg.sender, tokenAmount, totalCost);
    }

    function setTokenPrice(uint256 _tokenPrice) public onlyOwner {
        tokenPrice = _tokenPrice;
    }

    function setCommissionPercent(uint256 _commissionPercent) public onlyOwner {
        commissionPercent = _commissionPercent;
    }

    function setCommissionWallet(address _wallet) public onlyOwner {
        commissionWallet = _wallet;
    }

    function setTokenOwnerWallet(address _wallet) public onlyOwner {
        tokenOwnerWallet = _wallet;
    }

    function setTokenAddress(address _tokenAddress) public onlyOwner {
        token = IERC20(_tokenAddress);
    }

    function withdrawBNB() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
