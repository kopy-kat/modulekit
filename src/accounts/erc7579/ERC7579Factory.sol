// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../external/ERC7579.sol";
import { LibClone } from "solady/utils/LibClone.sol";

abstract contract ERC7579Factory {
    ERC7579Account internal implementation;
    ERC7579Bootstrap internal bootstrapDefault;

    constructor() {
        implementation = new ERC7579Account();
        bootstrapDefault = new ERC7579Bootstrap();
    }

    function createERC7579(bytes32 salt, bytes memory initCode) public returns (address account) {
        bytes32 _salt = _getSalt(salt, initCode);
        account = LibClone.cloneDeterministic(0, address(implementation), initCode, _salt);

        IMSA(account).initializeAccount(initCode);
    }

    function getAddressERC7579(bytes32 salt, bytes memory initCode) public view returns (address) {
        bytes32 _salt = _getSalt(salt, initCode);
        return LibClone.predictDeterministicAddress(
            address(implementation), initCode, _salt, address(this)
        );
    }

    function getInitDataERC7579(
        address validator,
        bytes memory initData
    )
        public
        returns (bytes memory init)
    {
        ERC7579BootstrapConfig[] memory _validators = new ERC7579BootstrapConfig[](1);
        _validators[0].module = validator;
        _validators[0].data = initData;
        ERC7579BootstrapConfig[] memory _executors = new ERC7579BootstrapConfig[](0);

        ERC7579BootstrapConfig memory _hook;

        ERC7579BootstrapConfig[] memory _fallBacks = new ERC7579BootstrapConfig[](0);
        init = abi.encode(
            address(bootstrapDefault),
            abi.encodeCall(ERC7579Bootstrap.initMSA, (_validators, _executors, _hook, _fallBacks))
        );
    }

    function _getSalt(bytes32 _salt, bytes memory initCode) internal pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_salt, initCode));
    }
}
