// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract TokenSale {
    IERC20 public saleToken;
    address payable public destinationWallet;
    uint256 public bnbPrice;
    uint256 public minPurchase;
    uint256 public maxPurchase;
    address public owner;
    bool private locked;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost, string paymentMethod);

    modifier onlyOwner() {
        require(msg.sender == owner, "Apenas o dono pode executar esta funcao");
        _;
    }

    modifier noReentrancy() {
        require(!locked, "Reentrancy detectada");
        locked = true;
        _;
        locked = false;
    }

     constructor() payable {
        owner = msg.sender;
        saleToken = IERC20(0xe584f4057284bCc379Af60cE1E34e960FB4BcAFE); // endereço do token
        destinationWallet = payable(0xEe02E32d8d2888E9f1D6d13391E716Bc7F41f6Ae); // carteira de recebimento
        bnbPrice = 1e15; // preço em wei (0.001 BNB)
        minPurchase = 1e8; // valor mínimo em wei
        maxPurchase = 1000e8; // valor máximo em wei
    }

    function buy() external payable noReentrancy {
        require(msg.value >= minPurchase, "Valor minimo nao atingido");
        require(msg.value <= maxPurchase, "Valor maximo excedido");

        uint256 decimalsFactor = 10 ** uint256(saleToken.decimals());
        uint256 tokenAmount = (msg.value * decimalsFactor) / bnbPrice;
        require(saleToken.transfer(msg.sender, tokenAmount), "Falha ao transferir tokens");

        (bool success, ) = destinationWallet.call{value: msg.value}("");
        require(success, "Falha ao enviar BNB");

        emit TokensPurchased(msg.sender, tokenAmount, msg.value, "BNB");
    }

    function updateSettings(
        address tokenAddress,
        address payable newDestination,
        uint256 newPrice
    ) external onlyOwner {
        saleToken = IERC20(tokenAddress);
        destinationWallet = newDestination;
        bnbPrice = newPrice;
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) destinationWallet.transfer(balance);

        uint256 tokenBalance = saleToken.balanceOf(address(this));
        if (tokenBalance > 0) saleToken.transfer(owner, tokenBalance);
    }
}
