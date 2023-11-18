// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.21;

import "./Tempest.sol";

contract TempestERC20 is Tempest {
    address public token;



    error TOKEN_TRANSFER_FAILED();

    constructor(
        IDepositVerifier _depositVerifier,
        IFullWithdrawVerifier _fullWithdrawVerifier,
        IPartialWithdrawVerifier _partialWithdrawVerifier,
        IShieldedTransferVerifier _shieldedTransferVerifier,
        IShieldedClaimVerifier _shieldedClaimVerifier,
        uint256 _merkleTreeHeight,
        address _token
    )
        Tempest(
            _depositVerifier,
            _fullWithdrawVerifier,
            _partialWithdrawVerifier,
            _shieldedTransferVerifier,
            _shieldedClaimVerifier,
            _merkleTreeHeight
        )
    {
        token = _token;
    }


    //@dev this function would be performing a transfer from the current caller (msg.sender)
    function _processDeposit() internal override {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(bytes4(keccak256("transferFrom(address,address,uint256)")), msg.sender, address(this), _amount)
        );

        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert TOKEN_TRANSFER_FAILED();
        }
    }

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
