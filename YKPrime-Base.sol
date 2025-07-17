// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
Gerado por:
Smart Contract Cafe
http://smartcontrat.cafe
*/

/// @title YKPrime-Base
/// @notice Lógica fixa do token (não pode ser alterada)
contract YKPrimeBase {
    // ============================
    // CONFIGURAÇÕES DO TOKEN
    // ============================
    string public constant TOKEN_NAME = "YKPrime Base";
    string public constant TOKEN_SYMBOL = "YKPBASE";
    uint8 public constant TOKEN_DECIMALS = 4;
    uint256 public constant TOKEN_SUPPLY = 50000000000 * (10 ** TOKEN_DECIMALS);
    address public constant TOKEN_OWNER = 0x0b81337F18767565D2eA40913799317A25DC4bc5;

    /// ============================
    /// Fallback para delegatecall
    /// ============================
    fallback() external payable {
        revert("This contract is logic only, call through Proxy");
    }

    receive() external payable {
        revert("Do not send ETH directly to this contract");
    }
}
