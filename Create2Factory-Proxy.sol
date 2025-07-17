// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Create2Factory
/// @notice Deploya contratos com endereço customizado usando CREATE2
contract Create2Factory is Ownable {
    event ContractDeployed(address deployedAt, bytes32 salt);

    /// @notice Construtor define o dono inicial
    constructor() Ownable(msg.sender) {}

    /// @notice Deploya contrato com CREATE2
    function deploy(bytes memory bytecode, bytes32 salt) external onlyOwner returns (address) {
        address deployedAddress;
        assembly {
            deployedAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(deployedAddress) {
                revert(0, 0)
            }
        }
        emit ContractDeployed(deployedAddress, salt);
        return deployedAddress;
    }

    /// @notice Calcula o endereço que será gerado com CREATE2
    function computeAddress(bytes memory bytecode, bytes32 salt) external view returns (address) {
        bytes32 hash = keccak256(bytecode);
        return address(uint160(uint256(keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, hash)
        ))));
    }
}
