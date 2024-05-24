// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution, IERC7579Account, ERC7579BootstrapConfig } from "../../external/ERC7579.sol";
import "erc7579/lib/ModeLib.sol";
import "erc7579/interfaces/IERC7579Module.sol";
import { PackedUserOperation, IEntryPoint } from "../../external/ERC4337.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { getAccountType, AccountType } from "src/accounts/MultiAccountHelpers.sol";
import { Safe7579Launchpad, ModuleInit } from "safe7579/Safe7579Launchpad.sol";
import { MultiAccountFactory } from "src/accounts/MultiAccountFactory.sol";
import { HookType } from "safe7579/DataTypes.sol";

interface IAccountModulesPaginated {
    function getValidatorPaginated(
        address,
        uint256
    )
        external
        view
        returns (address[] memory, address);

    function getExecutorsPaginated(
        address,
        uint256
    )
        external
        view
        returns (address[] memory, address);
}

interface ISafeFactory {
    function getInitDataSafe(
        address validator,
        bytes memory initData
    )
        external
        view
        returns (bytes memory init);
}

library ERC7579Helpers {
    /**
     * @dev install/uninstall a module on an ERC7579 account
     *
     * @param account IERC7579Account address
     * @param module IERC7579Module address
     * @param initData bytes encoded initialization data.
     *               initData will be passed to fn
     * @param fn function parameter that will yield the initData
     *
     * @return erc7579Tx bytes encoded single ERC7579Execution
     *
     *
     *
     *   can be used like so:
     *   bytes memory installCallData = configModule(
     *                        validator,
     *                        initData,
     *                        ERC7579Helpers.installValidator);
     *
     */
    function configModule(
        address account,
        uint256 moduleType,
        address module,
        bytes memory initData,
        function(address, uint256, address, bytes memory) internal  returns (bytes memory) fn
    )
        internal
        returns (bytes memory erc7579Tx)
    {
        erc7579Tx = fn(account, moduleType, module, initData);
    }

    function configModuleUserOp(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData,
        function(address, uint256, address, bytes memory) internal  returns (bytes memory) fn,
        address txValidator
    )
        internal
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        bool notDeployedYet = instance.account.code.length == 0;
        if (notDeployedYet) {
            initCode = instance.initCode;
        }

        bytes memory callData = configModule(instance.account, moduleType, module, initData, fn);

        AccountType env = getAccountType();
        if (env == AccountType.SAFE) {
            if (initCode.length != 0) {
                // TODO: refactor this to decode the initcode
                address factory;
                assembly {
                    factory := mload(add(initCode, 20))
                }
                Safe7579Launchpad.InitData memory initData = abi.decode(
                    ISafeFactory(factory).getInitDataSafe(address(txValidator), ""),
                    (Safe7579Launchpad.InitData)
                );
                // Safe7579Launchpad.InitData memory initData =
                //     abi.decode(_initCode, (Safe7579Launchpad.InitData));
                initData.callData = callData;
                initCode = abi.encodePacked(
                    factory,
                    abi.encodeCall(
                        MultiAccountFactory.createAccount, (instance.salt, abi.encode(initData))
                    )
                );
                callData = abi.encodeCall(Safe7579Launchpad.setupSafe, (initData));
            }
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(instance.account, instance.aux.entrypoint, txValidator),
            initCode: initCode,
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });

        userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
    }

    function execUserOp(
        AccountInstance memory instance,
        bytes memory callData,
        address txValidator
    )
        internal
        view
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        bool notDeployedYet = instance.account.code.length == 0;
        if (notDeployedYet) {
            initCode = instance.initCode;
        }

        AccountType env = getAccountType();
        if (env == AccountType.SAFE) {
            if (initCode.length != 0) {
                // TODO: refactor this to decode the initcode
                address factory;
                assembly {
                    factory := mload(add(initCode, 20))
                }
                Safe7579Launchpad.InitData memory initData = abi.decode(
                    ISafeFactory(factory).getInitDataSafe(address(txValidator), ""),
                    (Safe7579Launchpad.InitData)
                );
                // Safe7579Launchpad.InitData memory initData =
                //     abi.decode(_initCode, (Safe7579Launchpad.InitData));
                initData.callData = callData;
                initCode = abi.encodePacked(
                    factory,
                    abi.encodeCall(
                        MultiAccountFactory.createAccount, (instance.salt, abi.encode(initData))
                    )
                );
                callData = abi.encodeCall(Safe7579Launchpad.setupSafe, (initData));
            }
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(instance.account, instance.aux.entrypoint, txValidator),
            initCode: initCode,
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });

        userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
    }

    /**
     * Router function to install a module on an ERC7579 account
     */
    function installModule(
        address account,
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        internal
        view
        returns (bytes memory callData)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            return installValidator(account, module, initData);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            return installExecutor(account, module, initData);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            return installHook(account, module, initData);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            return installFallback(account, module, initData);
        } else {
            revert("Invalid module type");
        }
    }

    /**
     * Router function to uninstall a module on an ERC7579 account
     */
    function uninstallModule(
        address account,
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        internal
        view
        returns (bytes memory callData)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            return uninstallValidator(account, module, initData);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            return uninstallExecutor(account, module, initData);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            return uninstallHook(account, module, initData);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            return uninstallFallback(account, module, initData);
        } else {
            revert("Invalid module type");
        }
    }

    /**
     * get callData to install validator on ERC7579 Account
     */
    function installValidator(
        address account,
        address validator,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.installModule, (MODULE_TYPE_VALIDATOR, validator, initData)
        );
    }

    /**
     * get callData to uninstall validator on ERC7579 Account
     */
    function uninstallValidator(
        address account,
        address validator,
        bytes memory initData
    )
        internal
        view
        returns (bytes memory callData)
    {
        // get previous validator in sentinel list
        address previous;

        (address[] memory array,) =
            IAccountModulesPaginated(account).getValidatorPaginated(address(0x1), 100);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == validator) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == validator) previous = array[i - 1];
            }
        }

        callData = abi.encodeCall(
            IERC7579Account.uninstallModule,
            (MODULE_TYPE_VALIDATOR, validator, abi.encode(previous, initData))
        );
    }

    /**
     * get callData to install executor on ERC7579 Account
     */
    function installExecutor(
        address account,
        address executor,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.installModule, (MODULE_TYPE_EXECUTOR, executor, initData)
        );
    }

    /**
     * get callData to uninstall executor on ERC7579 Account
     */
    function uninstallExecutor(
        address account,
        address executor,
        bytes memory initData
    )
        internal
        view
        returns (bytes memory callData)
    {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array,) =
            IAccountModulesPaginated(account).getExecutorsPaginated(address(0x1), 100);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == executor) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == executor) previous = array[i - 1];
            }
        }

        callData = abi.encodeCall(
            IERC7579Account.uninstallModule,
            (MODULE_TYPE_EXECUTOR, executor, abi.encode(previous, initData))
        );
    }

    /**
     * get callData to install hook on ERC7579 Account
     */
    function installHook(
        address account,
        address hook,
        bytes memory initData
    )
        internal
        view
        returns (bytes memory callData)
    {
        AccountType env = getAccountType();
        if (env == AccountType.SAFE) {
            callData = abi.encodeCall(
                IERC7579Account.installModule,
                (MODULE_TYPE_HOOK, hook, abi.encode(HookType.GLOBAL, bytes4(0x0), initData))
            );
        } else {
            callData =
                abi.encodeCall(IERC7579Account.installModule, (MODULE_TYPE_HOOK, hook, initData));
        }
    }

    /**
     * get callData to uninstall hook on ERC7579 Account
     */
    function uninstallHook(
        address account,
        address hook,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        callData =
            abi.encodeCall(IERC7579Account.uninstallModule, (MODULE_TYPE_HOOK, hook, initData));
    }

    /**
     * get callData to install fallback on ERC7579 Account
     */
    function installFallback(
        address account,
        address fallbackHandler,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.installModule, (MODULE_TYPE_FALLBACK, fallbackHandler, initData)
        );
    }

    /**
     * get callData to uninstall fallback on ERC7579 Account
     */
    function uninstallFallback(
        address account,
        address fallbackHandler,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.uninstallModule, (MODULE_TYPE_FALLBACK, fallbackHandler, initData)
        );
    }

    /**
     * Encode a single ERC7579 Execution Transaction
     * @param target target of the call
     * @param value the value of the call
     * @param callData the calldata of the call
     */
    function encode(
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        pure
        returns (bytes memory erc7579Tx)
    {
        ModeCode mode = ModeLib.encode({
            callType: CALLTYPE_SINGLE,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });
        bytes memory data = abi.encodePacked(target, value, callData);
        return abi.encodeCall(IERC7579Account.execute, (mode, data));
    }

    /**
     * Encode a batched ERC7579 Execution Transaction
     * @param executions ERC7579 batched executions
     */
    function encode(Execution[] memory executions) internal pure returns (bytes memory erc7579Tx) {
        ModeCode mode = ModeLib.encode({
            callType: CALLTYPE_BATCH,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });
        return abi.encodeCall(IERC7579Account.execute, (mode, abi.encode(executions)));
    }

    /**
     * convert arrays to batched IERC7579Account
     */
    function toExecutions(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas
    )
        internal
        pure
        returns (Execution[] memory executions)
    {
        executions = new Execution[](targets.length);
        if (targets.length != values.length && values.length != callDatas.length) {
            revert("Length Mismatch");
        }

        for (uint256 i; i < targets.length; i++) {
            executions[i] =
                Execution({ target: targets[i], value: values[i], callData: callDatas[i] });
        }
    }

    function getNonce(
        address account,
        IEntryPoint entrypoint,
        address validator
    )
        internal
        view
        returns (uint256 nonce)
    {
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        nonce = entrypoint.getNonce(address(account), key);
    }

    function signatureInNonce(
        address account,
        IEntryPoint entrypoint,
        PackedUserOperation memory userOp,
        address validator,
        bytes memory signature
    )
        internal
        view
        returns (bytes32 userOpHash, PackedUserOperation memory)
    {
        userOp.nonce = getNonce(account, entrypoint, validator);
        userOp.signature = signature;

        userOpHash = entrypoint.getUserOpHash(userOp);
        return (userOpHash, userOp);
    }
}
