// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "forge-std/console.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";
import "src/integrations/aUSTVaultV2.sol";
import "./TestERC20.sol";
import "./Utils.sol";

// This test covers integration for UST vaults

contract TestanchorVault is DSTest {
    uint256 constant ADMINFEE = 100;
    uint256 constant CALLERFEE = 10;
    uint256 constant MAX_REINVEST_STALE = 1 hours;
    uint256 constant MAX_INT = 2**256 - 1;

    uint256 public MIN_FIRST_MINT;
    uint256 public FIRST_DONATION;
    uint256 public decimalCorrection;
    Vm public constant vm = Vm(HEVM_ADDRESS);

    IERC20 constant UST = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664); //UST (is actually USDC)
    address constant ustHolder = 0xCe2CC46682E9C6D5f174aF598fb4931a9c0bE68e;
    IERC20 constant AUST = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7); //AUST (is actually WAVAX)
    address constant austHolder = 0xBBff2A8ec8D702E61faAcCF7cf705968BB6a5baB;

    address constant pricefeed = 0x0A77230d17318075983913bC2145DB16C7366156; // this is actually avax/usd price feed
    address constant xAnchor = 0x95aE712C309D33de0250Edd0C2d7Cb1ceAFD4550;

    aUSTVault public vault;
    uint256 public underlyingBalance;

    function setUp() public {
        vault = new aUSTVault();
        vault.initialize(
            address(AUST),
            "Vault",
            "VAULT",
            ADMINFEE,
            CALLERFEE,
            MAX_REINVEST_STALE,
            address(AUST),
            address(pricefeed),
            address(xAnchor),
            address(UST),
            true
        );
        MIN_FIRST_MINT = 1e18;
        decimalCorrection = (10**(18 - AUST.decimals()));
        FIRST_DONATION = vault.FIRST_DONATION() / decimalCorrection;

        vm.startPrank(austHolder);
        AUST.transfer(address(this), AUST.balanceOf(austHolder));
        vm.stopPrank();
        vm.startPrank(ustHolder);
        UST.transfer(address(this), UST.balanceOf(ustHolder));
        vm.stopPrank();
        underlyingBalance = UST.balanceOf(address(this));
        vm.warp(block.timestamp + 10 days);
        UST.approve(address(vault), MAX_INT);
        // Transfers of AUST will be simulated to test different timings/cases
    }

    function testVanillaDepositUST() public returns (uint256) {
        uint256 amt = 10**9;
        uint256 preBalance = vault.balanceOf(address(this));
        vault.deposit(amt);
        uint256 postBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(postBalance == preBalance + amt - FIRST_DONATION);
        return amt;
    }

    // Here the value should return as expected
    function testTwoVanillaDepositsUST(uint256 amt) public returns (uint256) {
        if (amt > UST.balanceOf(address(this)) || amt == 0) {
            return 0;
        }
        uint256 initAmt = 10**9;
        uint256 preBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(postBalance == preBalance + initAmt - FIRST_DONATION);

        // Simulating wormhole transfer
        uint256 aUSTSimulatedAmount = (initAmt * vault._getUSTaUST()) / 1e18;
        AUST.transfer(address(vault), aUSTSimulatedAmount);

        // Second Deposit after wormhole transfer
        preBalance = vault.balanceOf(address(this));
        vault.deposit(amt);
        postBalance = vault.balanceOf(address(this)) / decimalCorrection;
        assertTrue(postBalance == preBalance + amt);
    }

    function testOneVanillaDepositOneFullRedeemUST(uint96 amt)
        public
        returns (uint256)
    {
        uint256 initAmt = 10**9;
        uint256 preTokenBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postTokenBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(
            postTokenBalance == preTokenBalance + initAmt - FIRST_DONATION
        );

        // Simulating wormhole transfer
        uint256 aUSTSimulatedAmount = (initAmt * vault._getUSTaUST()) / 1e18;
        AUST.transfer(address(vault), aUSTSimulatedAmount);

        uint256 preaUSTBalanceVault = AUST.balanceOf(address(vault));
        uint256 preaUSTBalanceUser = AUST.balanceOf(address(this));
        preTokenBalance = postTokenBalance;
        vault.redeem(preTokenBalance * decimalCorrection);
        uint256 postaUSTBalanceVault = AUST.balanceOf(address(vault));
        uint256 postaUSTBalanceUser = AUST.balanceOf(address(this));

        postTokenBalance = vault.balanceOf(address(this)) / decimalCorrection;
        assertTrue(
            preaUSTBalanceUser + (preaUSTBalanceVault - postaUSTBalanceVault) ==
                postaUSTBalanceUser
        );
        assertTrue(postTokenBalance == 0);
    }

    function testOneVanillaDepositOnePartialRedeemUST(uint96 amt)
        public
        returns (uint256)
    {
        uint256 initAmt = 10**9;
        uint256 preTokenBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postTokenBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(
            postTokenBalance == preTokenBalance + initAmt - FIRST_DONATION
        );

        // Simulating wormhole transfer
        uint256 aUSTSimulatedAmount = (initAmt * vault._getUSTaUST()) / 1e18;
        AUST.transfer(address(vault), aUSTSimulatedAmount);

        if (amt == 0 || amt > postTokenBalance) {
            return 0;
        }

        uint256 preaUSTBalanceVault = AUST.balanceOf(address(vault));
        uint256 preaUSTBalanceUser = AUST.balanceOf(address(this));
        preTokenBalance = postTokenBalance;
        vault.redeem(amt * decimalCorrection);
        uint256 postaUSTBalanceVault = AUST.balanceOf(address(vault));
        uint256 postaUSTBalanceUser = AUST.balanceOf(address(this));

        postTokenBalance = vault.balanceOf(address(this)) / decimalCorrection;
        assertTrue(
            preaUSTBalanceUser + (preaUSTBalanceVault - postaUSTBalanceVault) ==
                postaUSTBalanceUser
        );
        assertTrue(postTokenBalance == preTokenBalance - amt);
    }

    // Here the deposit and compound should go as expected.
    function testOneVanillaDepositOneCompoundUSTS(uint96 amt)
        public
        returns (uint256)
    {
        uint256 initAmt = 10**9;
        uint256 preTokenBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postTokenBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(
            postTokenBalance == preTokenBalance + initAmt - FIRST_DONATION
        );

        // Simulating wormhole transfer
        uint256 aUSTSimulatedAmount = (initAmt * vault._getUSTaUST()) / 1e18;
        AUST.transfer(address(vault), aUSTSimulatedAmount);

        uint256 preBalanceInUST = AUST.balanceOf(address(vault));
        vm.warp(block.timestamp + 100 days);
        vault.setMockPriceFeed(1e18 * 2); // Over time more UST for 1 AUST (yield)
        vault.compound();
        uint256 postBalanceInUST = AUST.balanceOf(address(vault)) * 2;
        assertTrue(postBalanceInUST > preBalanceInUST);
        return amt;
    }

    // There should be no out of the ordinary behavior. The balance should compound
    // after the deposit and should then be redeemed.
    function testOneVanillaDepositOneCompoundOneRedeemUST(uint96 amt)
        public
        returns (uint256)
    {
        uint256 initAmt = 10**9;
        uint256 preTokenBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postTokenBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(
            postTokenBalance == preTokenBalance + initAmt - FIRST_DONATION
        );

        // Simulating wormhole transfer
        uint256 aUSTSimulatedAmount = (initAmt * vault._getUSTaUST()) / 1e18;
        AUST.transfer(address(vault), aUSTSimulatedAmount);

        vm.warp(block.timestamp + 100 days);
        vault.compound();
        uint256 preaUSTBalanceVault = AUST.balanceOf(address(vault));
        uint256 preaUSTBalanceUser = AUST.balanceOf(address(this));
        preTokenBalance = postTokenBalance;
        vault.redeem(preTokenBalance * decimalCorrection);
        uint256 postaUSTBalanceVault = AUST.balanceOf(address(vault));
        uint256 postaUSTBalanceUser = AUST.balanceOf(address(this));

        postTokenBalance = vault.balanceOf(address(this)) / decimalCorrection;
        assertTrue(
            preaUSTBalanceUser + (preaUSTBalanceVault - postaUSTBalanceVault) ==
                postaUSTBalanceUser
        );
        assertTrue(postTokenBalance == 0);
    }

    /* THESE TESTS ARE EXPECTED TO FAIL */

    // Here the case where the aUST isn't recieved by the second deposit should
    // be tested. This would be an expected failure.
    function testOneVanillaOneBadDepositFromNoRecFunds(uint96 amt)
        public
        returns (uint256)
    {
        if (amt > UST.balanceOf(address(this)) || amt == 0) {
            return 0;
        }
        uint256 initAmt = 10**9;
        uint256 preBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(postBalance == preBalance + initAmt - FIRST_DONATION);

        // Here we are assuming there is no aUST received between the two deposits

        vault.deposit(amt);
    }

    // Here the case where the aUST is sent by some actor trying to get past the lock
    // this test should be expected to fail.
    function testOneVanillaOneBadDepositFromMicroDeposit(uint96 amt)
        public
        returns (uint256)
    {
        if (amt > UST.balanceOf(address(this)) || amt == 0) {
            return 0;
        }
        uint256 initAmt = 10**9;
        uint256 preBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(postBalance == preBalance + initAmt - FIRST_DONATION);

        // Here we are assuming that there is some kind of actor trying to bypass
        // the lock
        AUST.transfer(address(vault), 1);

        // Second Deposit after micro-deposit
        vault.deposit(amt);
    }

    // Here the deposit should go as expected, but the redeem should take place
    // before the aUST is recieved and should be an expected failure.
    function testOneVanillaDepositOneBadRedeemFromNoRecFunds(uint96 amt)
        public
        returns (uint256)
    {
        uint256 initAmt = 10**9;
        uint256 preTokenBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postTokenBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(
            postTokenBalance == preTokenBalance + initAmt - FIRST_DONATION
        );

        // No wormhole transfer

        vault.redeem(preTokenBalance * decimalCorrection);
    }

    // Here the deposit should go as expected, but the redeem should take place
    // before the aUST is recieved and should be an expected failure.
    function testOneVanillaDepositOneBadRedeemFromMicroDeposit(uint96 amt)
        public
        returns (uint256)
    {
        uint256 initAmt = 10**9;
        uint256 preTokenBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postTokenBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(
            postTokenBalance == preTokenBalance + initAmt - FIRST_DONATION
        );

        // Here we are assuming that there is some kind of actor trying to bypass
        // the lock
        AUST.transfer(address(vault), 1);

        vault.redeem(preTokenBalance * decimalCorrection);
    }

    // The compound should occur before the aUST is receieved.
    function testOneVanillaDepositOneBadCompound(uint96 amt)
        public
        returns (uint256)
    {
        uint256 initAmt = 10**9;
        uint256 preTokenBalance = vault.balanceOf(address(this));
        vault.deposit(initAmt);
        uint256 postTokenBalance = vault.balanceOf(address(this)) /
            decimalCorrection;
        assertTrue(
            postTokenBalance == preTokenBalance + initAmt - FIRST_DONATION
        );

        // No wormhole transfer

        vm.warp(block.timestamp + 1 days);
        vault.compound();
    }
}
