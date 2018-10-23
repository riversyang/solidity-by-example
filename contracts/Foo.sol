pragma solidity ^0.4.24;

contract Foo {
    address owner;
    uint256 state;
    address bar;

    constructor() public {
        owner = msg.sender;
        bar = new Bar();
    }

    function doChange() external returns(bool) {
        state = 1;
        Bar(bar).doRevert();
        return true;
        // return address(bar).call(bytes4(keccak256("doRevert()")));
    }

    function kill() external {
        Bar(bar).kill();
        selfdestruct(owner);
    }
}

contract Bar {
    address owner;

    constructor() public {
        owner = msg.sender;
    }

    function doRevert() external pure {
        revert("Should revert all state change.");
    }

    function kill() external {
        selfdestruct(owner);
    }
}