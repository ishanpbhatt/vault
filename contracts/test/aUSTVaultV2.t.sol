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
            address(UST)
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
        underlyingBalance = AUST.balanceOf(address(this));
        vm.warp(block.timestamp + 10 days);
        UST.approve(address(vault), MAX_INT);
        // Transfers of AUST will be simulated to test different timings/cases
    }

    function testVanillaDeposit(uint96 amt) public returns (uint256) {
        if (amt > underlyingBalance || amt < MIN_FIRST_MINT) {
            return 0;
        }
        uint256 preBalance = vault.balanceOf(address(this));
        vault.deposit(amt);
        uint256 postBalance = vault.balanceOf(address(this)) /
            decimalCorrection;

        console.log(postBalance);
        console.log(preBalance + amt - FIRST_DONATION);
        assertTrue(postBalance == preBalance + amt - FIRST_DONATION);
        return amt;
    }

    // Here the value should return as expected
    function testTwoVanillaDeposits(uint96 amt) public returns (uint256) {
        return 0;
    }

    // Here the case where the aUST isn't recieved by the second deposit should
    // be tested. This would be an expected failurre.
    function testOneVanillaOneBadDeposits(uint96 amt) public returns (uint256) {
        return 0;
    }

    // Here the deposit and redeem should be as expected
    function testOneVanillaDepositOneRedeem(uint96 amt)
        public
        returns (uint256)
    {
        return 0;
    }

    // Here the deposit should go as expected, but the redeem should take place
    // before the aUST is recieved and should be an expected failure.
    function testOneVanillaDepositOneBadRedeem(uint96 amt)
        public
        returns (uint256)
    {
        return 0;
    }

    // Here the deposit and compound should go as expected.
    function testOneVanillaDepositOneCompound(uint96 amt)
        public
        returns (uint256)
    {
        return 0;
    }

    // The compound should occur before the aUST is receieved. Expected failure.
    function testOneVanillaDepositOneBadCompound(uint96 amt)
        public
        returns (uint256)
    {
        return 0;
    }

    // There should be no out of the ordinary behavior. The balance should compound
    // after the deposit and should then be redeemed.
    function testOneVanillaDepositOneCompoundOneRedeem(uint96 amt)
        public
        returns (uint256)
    {
        return 0;
    }

    // The compound should occur before the aUST is receieved. Expected failure.
    // But upon the redeem the aUST is receieved and the compound is handled. This
    // should end with the same overall balances as the above test.
    function testOneVanillaDepositOneBadCompoundOneRedeem(uint96 amt)
        public
        returns (uint256)
    {
        return 0;
    }
}
