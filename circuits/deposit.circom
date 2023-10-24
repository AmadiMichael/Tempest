pragma circom 2.0.0;

include "./components/depositComponent.circom";

component main {public [oldRoot, commitmentHash, denomination, root]} = Deposit(20);
