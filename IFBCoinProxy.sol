// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IFBCoinProxy (ERC1967 Proxy)
 * @dev Proxy contract that delegates calls to an implementation contract (IFBCoin)
 *      and stores the implementation address in a fixed EIP-1967 storage slot.
 */
contract IFBCoinProxy {
    // keccak256("eip1967.proxy.implementation") - 1
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Deploys the proxy and initializes the implementation.
     * @param _logic Address of the implementation contract (IFBCoin)
     * @param _data Initialization data encoded as bytes (call to initialize)
     */
    constructor(address _logic, bytes memory _data) payable {
        require(_logic != address(0), "Invalid implementation address");

        // Store the implementation address in the EIP-1967 slot
        assembly {
            sstore(_IMPLEMENTATION_SLOT, _logic)
        }

        // Call initialize on the implementation if _data is provided
        if (_data.length > 0) {
            (bool success, ) = _logic.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }

    /**
     * @dev Fallback function that delegates all calls to the implementation.
     */
    fallback() external payable {
        _delegate();
    }

    receive() external payable {
        _delegate();
    }

    /**
     * @dev Delegates the current call to the implementation contract.
     */
    function _delegate() internal {
        address impl;
        assembly {
            impl := sload(_IMPLEMENTATION_SLOT)
        }
        require(impl != address(0), "Implementation not set");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
                case 0 { revert(0, returndatasize()) }
                default { return(0, returndatasize()) }
        }
    }
}
