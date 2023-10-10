pragma circom 2.0.0;

include "depositComponent.circom";

component main {public [oldRoot, commitmentHash, denomination, root]} = Deposit(20);
