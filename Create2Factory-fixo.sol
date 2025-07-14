// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CloneFactory {
    event CloneCreated(address indexed cloneAddress, uint256 salt);

    address public immutable implementation;

    constructor() {
        // Define o contrato base (espelho fixo)
        implementation = 0x1ddB102b41920F552d388ED6b8eA47eE8C4CCAfe;
    }

    function createClone(uint256 salt) external returns (address cloneAddress) {
        bytes20 targetBytes = bytes20(implementation);

        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3) // prefixo constructor
            mstore(add(clone, 0x14), shl(0x60, targetBytes)) // endereço do contrato base
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf3) // sufixo constructor
            cloneAddress := create2(0, clone, 0x37, salt)
        }

        require(cloneAddress != address(0), "Deploy failed");

        emit CloneCreated(cloneAddress, salt);
    }

    function predictCloneAddress(uint256 salt) external view returns (address predicted) {
        bytes20 targetBytes = bytes20(implementation);
        bytes memory clone = abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            targetBytes,
            hex"5af43d82803e903d91602b57fd5bf3"
        );

        bytes32 bytecodeHash = keccak256(clone);

        predicted = address(uint160(uint(keccak256(abi.encodePacked(
            hex"ff",
            address(this),
            salt,
            bytecodeHash
        )))));
    }
}
