// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title YKPrime-Proxy
/// @notice Proxy que armazena estado e delega chamadas ao Base
contract YKPrimeProxy {
    address public implementation; // Endereço do contrato Base (lógica)
    address public owner;          // Dono do Proxy

    event ImplementationChanged(address newImplementation);
    event OwnershipTransferred(address previousOwner, address newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    /// @notice Construtor define o contrato Base e o dono inicial
    constructor(address _implementation) {
        require(_implementation != address(0), "Invalid implementation address");
        implementation = _implementation;
        owner = msg.sender; // Define o dono como quem fez o deploy
    }

    /// @notice Permite atualizar o contrato Base
    function setImplementation(address newImplementation) external onlyOwner {
        require(newImplementation != address(0), "Invalid implementation address");
        implementation = newImplementation;
        emit ImplementationChanged(newImplementation);
    }

    /// @notice Transfere a propriedade do Proxy
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Fallback delega todas as chamadas ao Base
    fallback() external payable {
        address impl = implementation;
        require(impl != address(0), "Implementation not set");

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    /// @notice Receive ETH diretamente
    receive() external payable {
        // Apenas aceita ETH sem lógica extra
    }
}
