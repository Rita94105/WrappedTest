// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Wrapped} from "../src/Wrapped.sol";

contract WrappedTest is Test{
    Wrapped public wrapped;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    function setUp() public {
        wrapped = new Wrapped{value: 10 ether}();
    }

    function testDeposit() public 
    {
        address user = makeAddr("user");
        vm.startPrank(user);
        deal(user,10 ether);

        uint256 contractEth = address(wrapped).balance;
        uint256 userToken = wrapped.balanceOf(user);

        //3. deposit 應該要 emit Deposit event
        vm.expectEmit(true, true, false, false);
        emit Deposit(user, 1 ether);

        (bool success, ) = address(wrapped).call{value: 1 ether}(abi.encodeWithSignature("deposit()"));
        require(success);
        assertEq(success,true,"Fail to deposit()");
        //1. deposit 應該將與 msg.value 相等的 ERC20 token mint 給 user
        uint256 newUserToken = wrapped.balanceOf(user);
        assertEq(newUserToken, userToken + 1 ether);
        //2. deposit 應該將 msg.value 的 ether 轉入合約
        uint256 newcontractEth = address(wrapped).balance;
        assertEq(newcontractEth, contractEth + 1 ether);

        vm.stopPrank();
    }

    function testWithdraw() public {
        address user = makeAddr("user");
        vm.startPrank(user);
        deal(user,10 ether);

        //先存錢才能測試提款
        (bool deposit, ) = address(wrapped).call{value: 2 ether}(abi.encodeWithSignature("deposit()"));
        require(deposit);
        assertEq(deposit,true,"fail to deposit for test");
        uint256 total = wrapped.getSupply();
        uint256 userEth = address(user).balance;

        //6. withdraw 應該要 emit Withdraw event
        vm.expectEmit(true, true, false, false);
        emit Withdrawal(user, 1 ether);

        (bool success,) = address(wrapped).call(abi.encodeWithSignature("withdraw(uint256)", 1 ether));
        require(success);
        assertEq(success,true,"Fail to withdraw");
        
        //4. withdraw 應該要 burn 掉與 input parameters 一樣的 erc20 token
        uint256 newTotal = wrapped.getSupply();
        assertEq(newTotal,total - 1 ether);

        //5. withdraw 應該將 burn 掉的 erc20 換成 ether 轉給 user
        uint256 newUserEth = address(user).balance;
        assertEq(newUserEth, userEth + 1 ether);

        vm.stopPrank();
    }

    function testTransfer() public {
        address sender = makeAddr("sender");
        address receiver = makeAddr("receiver");
        vm.startPrank(sender);
        deal(sender,10 ether);

        //先存錢才能測試提款
        (bool deposit, ) = address(wrapped).call{value: 2 ether}(abi.encodeWithSignature("deposit()"));
        require(deposit);
        assertEq(deposit,true,"fail to deposit for test");
        uint256 senderToken = wrapped.balanceOf(sender);
        uint256 receiverToken = wrapped.balanceOf(receiver);

        //emit Transfer event
        vm.expectEmit(true, true, false, false);
        emit Transfer(sender,receiver, 1 ether);

        (bool success, ) = address(wrapped).call(abi.encodeWithSignature("transfer(address,uint256)", receiver,1 ether));
        require(success);
        assertEq(success,true,"fail to transfer");

        //7. transfer 應該要將 erc20 token 轉給別人
        uint256 newSenderToken = wrapped.balanceOf(sender);
        uint256 newReceiverToken = wrapped.balanceOf(receiver);
        assertEq(newSenderToken,senderToken - 1 ether);
        assertEq(newReceiverToken, receiverToken + 1 ether);

        vm.stopPrank();
    }

    function testApprove() public {
        address owner = makeAddr("owner");
        address spender = makeAddr("spender");

        vm.startPrank(owner);
        uint256 approveToken = wrapped.allowance(owner,spender);

        //emit Transfer event
        vm.expectEmit(true, true, false, false);
        emit Approval(owner,spender, 1 ether);

        (bool success, ) = address(wrapped).call(abi.encodeWithSignature("approve(address,uint256)", spender,1 ether));
        require(success);
        assertEq(success,true,"fail to approve");

        //8. approve 應該要給他人 allowance
        uint256 newApproveToken = wrapped.allowance(owner,spender);
        assertEq(newApproveToken, approveToken + 1 ether);

        vm.stopPrank();
    }

    function testTransferFrom() public {
        address owner = makeAddr("owner");
        address spender = makeAddr("spender");
        address to = makeAddr("to");
        deal(owner, 10 ether);
        
        vm.startPrank(owner);
        //先存錢才能測試轉帳
        (bool deposit, ) = address(wrapped).call{value: 2 ether}(abi.encodeWithSignature("deposit()"));
        require(deposit);
        assertEq(deposit,true,"fail to deposit for test");
        
        //要先授權才能測試代理人
        (bool approve, ) = address(wrapped).call(abi.encodeWithSignature("approve(address,uint256)", spender,1 ether));
        require(approve);
        assertEq(approve,true,"fail to approve");

        uint256 approveToken = wrapped.allowance(owner,spender);
        uint256 ownerToken = wrapped.balanceOf(owner);

        vm.stopPrank();

        vm.startPrank(spender);

        //9. transferFrom 應該要可以使用他人的 allowance
        vm.expectEmit(true, true, false, false);
        emit Transfer(owner,to, 1 ether);

        (bool success, ) = address(wrapped).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", owner, to,.5 ether));
        require(success);
        assertEq(success,true,"fail to transferFrom");

        //10. transferFrom 後應該要減除用完的 allowance
        uint256 newAproveToken = wrapped.allowance(owner,spender);
        assertEq(newAproveToken, approveToken - .5 ether);

        //檢查owner的token是否有轉給別人
        uint newOwnerToken = wrapped.balanceOf(owner);
        assertEq(newOwnerToken, ownerToken - .5 ether);

        vm.stopPrank();
    }
}