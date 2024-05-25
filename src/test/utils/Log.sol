// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

function writeExpectRevert(uint256 value) {
    bytes32 slot = keccak256("ModuleKit.ExpectSlot");
    assembly {
        sstore(slot, value)
    }
}

function writeExpectRevertBytes4(bytes4 message) {
    bytes32 slot = keccak256("ModuleKit.ExpectSlot");
    // solhint-disable-next-line no-inline-assembly
    assembly {
        sstore(slot, message)
    }
}

function writeExpectRevertBytes(bytes memory message) {
    bytes32 slot = keccak256("ModuleKit.ExpectSlot");
    // solhint-disable-next-line no-inline-assembly
    assembly {
        sstore(slot, message)
    }
}

function getExpectRevert() view returns (uint256 value) {
    bytes32 slot = keccak256("ModuleKit.ExpectSlot");
    assembly {
        value := sload(slot)
    }
}

function getExpectRevertBytes4() view returns (bytes4 message) {
    bytes32 slot = keccak256("ModuleKit.ExpectSlot");
    // solhint-disable-next-line no-inline-assembly
    assembly {
        message := sload(slot)
    }
}

function getExpectRevertBytes() view returns (bytes memory message) {
    bytes32 slot = keccak256("ModuleKit.ExpectSlot");
    // solhint-disable-next-line no-inline-assembly
    assembly {
        message := sload(slot)
    }
}

function writeGasIdentifier(string memory id) {
    bytes32 slot = keccak256("ModuleKit.GasIdentifierSlot");
    assembly {
        sstore(slot, id)
    }
}

function getGasIdentifier() view returns (string memory id) {
    bytes32 slot = keccak256("ModuleKit.GasIdentifierSlot");
    assembly {
        id := sload(slot)
    }
}

function writeSimulateUserOp(bool value) {
    bytes32 slot = keccak256("ModuleKit.SimulateUserOp");
    assembly {
        sstore(slot, value)
    }
}

function getSimulateUserOp() view returns (bool value) {
    bytes32 slot = keccak256("ModuleKit.SimulateUserOp");
    assembly {
        value := sload(slot)
    }
}

library ModuleKitLogs {
    /* solhint-disable event-name-camelcase */
    event ModuleKit_NewAccount(address account, string accountType);
    event ModuleKit_Exec4337(address sender);

    event ModuleKit_AddExecutor(address account, address executor);
    event ModuleKit_RemoveExecutor(address account, address executor);

    event ModuleKit_AddValidator(address account, address validator);
    event ModuleKit_RemoveValidator(address account, address validator);

    event ModuleKit_SetFallback(address account, bytes4 functionSig, address handler);

    event ModuleKit_SetCondition(address account, address executor);
    /* solhint-enable event-name-camelcase */
}
