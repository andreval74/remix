
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
CREATE2Factory
Utilizado para gerar contratos inteligentes com endereços determinísticos.
Aceita bytecode e salt, calcula o endereço e faz o deploy usando CREATE2.
Compatível com contratos gerados com parâmetros via constructor.
*/

contract CREATE2Factory {
    event Deployed(address addr, uint256 salt);

    /// @notice Faz o deploy do contrato usando bytecode e salt (uint256)
    function deploy(bytes memory bytecode, uint256 salt) public returns (address addr) {
        require(bytecode.length > 0, "Bytecode vazio");

        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) { revert(0, 0) }
        }

        emit Deployed(addr, salt);
    }

    /// @notice Retorna o endereço do contrato que será criado com o bytecode e salt fornecidos
    function getAddress(bytes memory bytecode, uint256 salt) public view returns (address) {
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
