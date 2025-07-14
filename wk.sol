// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MTKMToken
 * @dev Token ERC20 gerado pelo Sistema Linear de Tokens
 * Nome: Webkeeper Coin
 * Símbolo: MTKM
 * Decimais: 18
 * Total Supply: 290000000000
 * Proprietário: 0x0b81337f18767565d2ea40913799317a25dc4bc5
 * Imagem: https://t4.ftcdn.net/jpg/01/79/72/79/360_F_179727950_zFqHumZcCdUoiaefTeJkTMjpekGDLj8A.jpg
 * Tipo de Deploy: CREATE2 (Endereço Personalizado)
 */
contract MTKMToken is ERC20, ERC20Burnable, Ownable {
    
    // Metadados do token
    string private _tokenImage;
    
    // Eventos
    event TokenImageUpdated(string newImage);
    
    /**
     * @dev Constructor que inicializa o token
     * @param initialOwner Endereço do proprietário inicial
     */
    constructor(address initialOwner) 
        ERC20("Webkeeper Coin", "MTKM") 
        Ownable(initialOwner)
    {
        // Mint do total supply para o proprietário
        _mint(initialOwner, ethers.parseUnits(tokenData.totalSupply, tokenData.decimals));
        
        // Definir imagem do token se fornecida
        _tokenImage = "https://t4.ftcdn.net/jpg/01/79/72/79/360_F_179727950_zFqHumZcCdUoiaefTeJkTMjpekGDLj8A.jpg";
    }
    
    /**
     * @dev Retorna o número de decimais do token
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    /**
     * @dev Retorna a URL da imagem do token
     */
    function tokenImage() public view returns (string memory) {
        return _tokenImage;
    }
    
    /**
     * @dev Atualiza a URL da imagem do token (apenas proprietário)
     * @param newImage Nova URL da imagem
     */
    function setTokenImage(string memory newImage) public onlyOwner {
        _tokenImage = newImage;
        emit TokenImageUpdated(newImage);
    }
    
    /**
     * @dev Mint de novos tokens (apenas proprietário)
     * @param to Endereço que receberá os tokens
     * @param amount Quantidade de tokens a serem mintados
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Função para receber Ether (caso necessário)
     */
    receive() external payable {
        // Token pode receber Ether se necessário
    }
    
    /**
     * @dev Função para retirar Ether do contrato (apenas proprietário)
     */
    function withdrawEther() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    /**
     * @dev Função para retirar tokens ERC20 enviados por engano (apenas proprietário)
     * @param token Endereço do token a ser retirado
     * @param amount Quantidade a ser retirada
     */
    function withdrawToken(address token, uint256 amount) public onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}

/**
 * @title MTKMTokenFactory
 * @dev Factory para deploy do token usando CREATE2 (se aplicável)
 */
contract MTKMTokenFactory {
    
    event TokenDeployed(address indexed tokenAddress, address indexed owner, bytes32 salt);
    
    /**
     * @dev Deploy do token usando CREATE2 (endereço personalizado)
     * @param salt Salt para determinismo do endereço
     * @param owner Proprietário do token
     */
    function deployTokenCREATE2(bytes32 salt, address owner) external returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(MTKMToken).creationCode,
            abi.encode(owner)
        );
        
        address tokenAddress;
        assembly {
            tokenAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(tokenAddress)) {
                revert(0, 0)
            }
        }
        
        emit TokenDeployed(tokenAddress, owner, salt);
        return tokenAddress;
    }
    
    /**
     * @dev Deploy do token usando CREATE (endereço padrão)
     * @param owner Proprietário do token
     */
    function deployToken(address owner) external returns (address) {
        MTKMToken token = new MTKMToken(owner);
        
        emit TokenDeployed(address(token), owner, bytes32(0));
        return address(token);
    }
    
    /**
     * @dev Calcula o endereço que seria gerado com CREATE2
     * @param salt Salt para o cálculo
     * @param owner Proprietário do token
     */
    function predictTokenAddress(bytes32 salt, address owner) external view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(MTKMToken).creationCode,
            abi.encode(owner)
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );
        
        return address(uint160(uint256(hash)));
    }
}