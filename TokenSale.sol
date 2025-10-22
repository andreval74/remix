// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract TokenSale {
    // === Variáveis de Estado ===
    IERC20 public immutable saleToken;       // Token sendo vendido (imutável após deploy)
    address payable public destinationWallet; // Carteira para receber BNB
    uint256 public bnbPrice;                // Preço por token em WEI (ex: 1e15 = 0.001 BNB)
    uint256 public minPurchase;             // Valor mínimo de compra em WEI
    uint256 public maxPurchase;             // Valor máximo de compra em WEI
    address public owner;                   // Dono do contrato
    bool private locked;                    // Proteção contra reentrancy

    // === Eventos ===
    event TokensPurchased(
        address indexed buyer,
        uint256 tokenAmount,
        uint256 bnbAmount,
        string paymentMethod
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // === Modificadores ===
    modifier onlyOwner() {
        require(msg.sender == owner, "TokenSale: chamador nao e o dono");
        _;
    }

    modifier noReentrancy() {
        require(!locked, "TokenSale: reentrancy detectada");
        locked = true;
        _;
        locked = false;
    }

    // === Construtor ===
    constructor(
        address _tokenAddress,
        address payable _destinationWallet,
        uint256 _bnbPrice,
        uint256 _minPurchase,
        uint256 _maxPurchase
    ) {
        require(_tokenAddress != address(0), "TokenSale: endereco do token invalido");
        require(_destinationWallet != address(0), "TokenSale: carteira de destino invalida");
        require(_bnbPrice > 0, "TokenSale: preco deve ser maior que 0");
        require(_minPurchase > 0, "TokenSale: valor minimo deve ser maior que 0");
        require(_maxPurchase >= _minPurchase, "TokenSale: valor maximo deve ser >= minimo");

        saleToken = IERC20(_tokenAddress);
        destinationWallet = _destinationWallet;
        bnbPrice = _bnbPrice;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        owner = msg.sender;
    }

    // === Funções Principais ===
    function buy() external payable noReentrancy {
        require(msg.value >= minPurchase, "TokenSale: valor minimo nao atingido");
        require(msg.value <= maxPurchase, "TokenSale: valor maximo excedido");
        require(msg.value > 0, "TokenSale: valor deve ser maior que 0");

        uint256 decimalsFactor = 10 ** uint256(saleToken.decimals());
        uint256 tokenAmount = (msg.value * decimalsFactor) / bnbPrice;

        // Transferência segura (com verificação de retorno)
        bool transferSuccess = saleToken.transfer(msg.sender, tokenAmount);
        require(transferSuccess, "TokenSale: falha ao transferir tokens");

        // Envio de BNB para a carteira de destino (com limite de gas)
        (bool sent, ) = destinationWallet.call{value: msg.value}("");
        require(sent, "TokenSale: falha ao enviar BNB");

        emit TokensPurchased(msg.sender, tokenAmount, msg.value, "BNB");
    }

    // === Funções de Administração ===
    function updateSettings(
        address _newTokenAddress,
        address payable _newDestinationWallet,
        uint256 _newBnbPrice,
        uint256 _newMinPurchase,
        uint256 _newMaxPurchase
    ) external onlyOwner {
        require(_newTokenAddress != address(0), "TokenSale: endereco do token invalido");
        require(_newDestinationWallet != address(0), "TokenSale: carteira de destino invalida");
        require(_newBnbPrice > 0, "TokenSale: preco deve ser maior que 0");
        require(_newMinPurchase > 0, "TokenSale: valor minimo deve ser maior que 0");
        require(_newMaxPurchase >= _newMinPurchase, "TokenSale: valor maximo deve ser >= minimo");

        // Nota: Não é possível modificar `saleToken` porque é `immutable`.
        // Para alterar o token, seria necessário redeployar o contrato.
        destinationWallet = _newDestinationWallet;
        bnbPrice = _newBnbPrice;
        minPurchase = _newMinPurchase;
        maxPurchase = _newMaxPurchase;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "TokenSale: novo dono nao pode ser endereco zero");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    // === Funções de Emergência ===
    function emergencyWithdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        if (contractBalance > 0) {
            (bool success, ) = destinationWallet.call{value: contractBalance}("");
            require(success, "TokenSale: falha ao retirar BNB");
        }

        uint256 tokenBalance = saleToken.balanceOf(address(this));
        if (tokenBalance > 0) {
            bool transferSuccess = saleToken.transfer(owner, tokenBalance);
            require(transferSuccess, "TokenSale: falha ao retirar tokens");
        }
    }

    // Função para resgatar BNB enviado acidentalmente ao contrato
    function withdrawAccidentalBNB() external onlyOwner {
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "TokenSale: falha ao retirar BNB");
    }

    // === Funções de Consulta ===
    function getTokenAddress() external view returns (address) {
        return address(saleToken);
    }

    function getCurrentPrice() external view returns (uint256) {
        return bnbPrice;
    }
}