// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.21;

import "./Tempest.sol";

contract TempestEth is Tempest {
    constructor(
        IDepositVerifier _depositVerifier,
        IFullWithdrawVerifier _fullWithdrawVerifier,
        IPartialWithdrawVerifier _partialWithdrawVerifier,
        IShieldedTransferVerifier _shieldedTransferVerifier,
        IShieldedClaimVerifier _shieldedClaimVerifier,
        uint256 _merkleTreeHeight
    )
        Tempest(
            _depositVerifier,
            _fullWithdrawVerifier,
            _partialWithdrawVerifier,
            _shieldedTransferVerifier,
            _shieldedClaimVerifier,
            _merkleTreeHeight
        )
    {}

    function _processDeposit() internal override {}

    function _processWithdraw(address payable _recipient, uint256 _amount, address payable _relayer, uint256 _fee)
        internal
        override
    {
        // sanity checks
        require(msg.value == 0, "Message value is supposed to be zero for ETH instance");

        unchecked {
            // safe unchecked block since all calls to this function already check that fee <= amount
            (bool success,) = _recipient.call{value: (_amount - _fee)}("");
            require(success, "payment to _recipient did not go through");
            if (_fee > 0) {
                (success,) = _relayer.call{value: _fee}("");
                require(success, "payment to _relayer did not go through");
            }
        }
    }
}
