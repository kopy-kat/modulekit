// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import { SafeERC7579 } from "src/SafeERC7579.sol";
import { ModuleManager } from "src/core/ModuleManager.sol";
import { MockValidator } from "./mocks/MockValidator.sol";
import { MockRegistry } from "./mocks/MockRegistry.sol";
import { MockExecutor } from "./mocks/MockExecutor.sol";
import { MockFallback } from "./mocks/MockFallback.sol";
import { MockTarget } from "./mocks/MockTarget.sol";

import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import {
    SafeProxy,
    SafeProxyFactory
} from "@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import "src/utils/Launchpadv2.sol";
import "src/utils/SignerFactory.sol";
import "src/interfaces/ISafe7579Init.sol";

import { Solarray } from "solarray/Solarray.sol";
import "./dependencies/EntryPoint.sol";

contract LaunchpadBase is Test {
    SafeERC7579 safe7579;
    Safe singleton;
    Safe safe;
    SafeProxyFactory safeProxyFactory;
    Safe7579Launchpad launchpad;

    MockValidator defaultValidator;
    MockExecutor defaultExecutor;

    Account signer1 = makeAccount("signer1");
    Account signer2 = makeAccount("signer2");

    IEntryPoint entrypoint;
    bytes userOpInitCode;
    IERC7484 registry;

    struct Setup {
        address singleton;
        address signerFactory;
        bytes signerData;
        address setupTo;
        bytes setupData;
        address fallbackHandler;
    }

    function setUp() public virtual {
        // Set up EntryPoint
        entrypoint = etchEntrypoint();
        singleton = new Safe();
        safeProxyFactory = new SafeProxyFactory();
        registry = new MockRegistry();
        safe7579 = new SafeERC7579();
        launchpad = new Safe7579Launchpad(address(entrypoint), registry);

        // Set up Modules
        defaultValidator = new MockValidator();
        defaultExecutor = new MockExecutor();

        bytes32 salt;

        ISafe7579Init.ModuleInit[] memory validators = new ISafe7579Init.ModuleInit[](1);
        validators[0] =
            ISafe7579Init.ModuleInit({ module: address(defaultValidator), initData: bytes("") });
        ISafe7579Init.ModuleInit[] memory executors = new ISafe7579Init.ModuleInit[](1);
        executors[0] =
            ISafe7579Init.ModuleInit({ module: address(defaultExecutor), initData: bytes("") });
        ISafe7579Init.ModuleInit[] memory fallbacks = new ISafe7579Init.ModuleInit[](0);
        ISafe7579Init.ModuleInit memory hook =
            ISafe7579Init.ModuleInit({ module: address(0), initData: bytes("") });

        Safe7579Launchpad.InitData memory initData = Safe7579Launchpad.InitData({
            singleton: address(singleton),
            owners: Solarray.addresses(signer1.addr),
            threshold: 1,
            setupTo: address(launchpad),
            setupData: abi.encodeCall(
                Safe7579Launchpad.initSafe7579,
                (
                    address(safe7579),
                    new ISafe7579Init.ModuleInit[](0),
                    executors,
                    fallbacks,
                    hook,
                    Solarray.addresses(makeAddr("attester1"), makeAddr("attester2")),
                    2
                )
            ),
            safe7579: address(safe7579),
            validators: validators,
            callData: ""
        });
        bytes32 initHash = launchpad.hash(initData);

        bytes memory factoryInitializer =
            abi.encodeCall(Safe7579Launchpad.preValidationSetup, (initHash, address(0), ""));

        PackedUserOperation memory userOp =
            getDefaultUserOp(address(safe), address(defaultValidator));

        {
            userOp.callData = abi.encodeCall(Safe7579Launchpad.setupSafe, (initData));
            userOp.initCode = _initCode(factoryInitializer, salt);
        }

        address predict = launchpad.predictSafeAddress({
            singleton: address(launchpad),
            safeProxyFactory: address(safeProxyFactory),
            creationCode: type(SafeProxy).creationCode,
            salt: salt,
            factoryInitializer: factoryInitializer
        });
        userOp.sender = predict;
        assertEq(userOp.sender, predict);
        userOp.signature = abi.encodePacked(
            uint48(0), uint48(type(uint48).max), hex"4141414141414141414141414141414141"
        );

        bytes32 userOpHash = entrypoint.getUserOpHash(userOp);
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        deal(address(userOp.sender), 1 ether);

        entrypoint.handleOps(userOps, payable(address(0x69)));

        safe = Safe(payable(predict));
    }

    function _initCode(
        bytes memory initializer,
        bytes32 salt
    )
        internal
        view
        returns (bytes memory _initCode)
    {
        _initCode = abi.encodePacked(
            address(safeProxyFactory),
            abi.encodeCall(
                SafeProxyFactory.createProxyWithNonce,
                (address(launchpad), initializer, uint256(salt))
            )
        );
    }

    function test_foo() public {
        assertTrue(true);
    }

    function getDefaultUserOp(
        address account,
        address validator
    )
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        userOp = PackedUserOperation({
            sender: account,
            nonce: safe7579.getNonce(account, validator),
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }
}
