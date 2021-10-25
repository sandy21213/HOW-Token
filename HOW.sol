/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

import "./HOW-import1.sol";
import "./HOW-imports.sol";


abstract contract Tokenomics {
    
    using SafeMath for uint256;
    
    // --------------------- Token Settings ------------------- //

    string internal constant NAME = "HOW";
    string internal constant SYMBOL = "HOW";
    
    uint16 internal constant FEES_DIVISOR = 10**3;
    uint8 internal constant DECIMALS = 9;
    uint256 internal constant ZEROES = 10**DECIMALS;
    
    uint256 private constant MAX = ~uint256(0);
    uint256 internal constant TOTAL_SUPPLY = 1000000000000000000 * ZEROES;
    uint256 internal _reflectedSupply = (MAX - (MAX % TOTAL_SUPPLY));

    /**
     * @dev Set the maximum transaction amount allowed in a transfer.
     * 
     * The default value is 1% of the total supply. 
     * 
     * NOTE: set the value to `TOTAL_SUPPLY` to have an unlimited max, i.e.
     * `maxTransactionAmount = TOTAL_SUPPLY;`
     */
    uint256 internal constant maxTransactionAmount = TOTAL_SUPPLY /100; // 1% of the total supply
    
    /**
     * @dev Set the maximum allowed balance in a wallet.
     * 
     * The default value is 2% of the total supply. 
     * 
     * NOTE: set the value to 0 to have an unlimited max.
     *
     * IMPORTANT: This value MUST be greater than `numberOfTokensToSwapToLiquidity` set below,
     * otherwise the liquidity swap will never be executed
     */ 
    uint256 internal constant maxWalletBalance = TOTAL_SUPPLY/1000; // 4% of the total supply
    
    /**
     * @dev Set the number of tokens to swap and add to liquidity. 
     * 
     * Whenever the contract's balance reaches this number of tokens, swap & liquify will be 
     * executed in the very next transfer (via the `_beforeTokenTransfer`)
     * 
     * If the `FeeType.Liquidity` is enabled in `FeesSettings`, the given % of each transaction will be first
     * sent to the contract address. Once the contract's balance reaches `numberOfTokensToSwapToLiquidity` the
     * `swapAndLiquify` of `Liquifier` will be executed. Half of the tokens will be swapped for ETH 
     * (or BNB on BSC) and together with the other half converted into a Token-ETH/Token-BNB LP Token.
     * 
     * See: `Liquifier`
     */
    uint256 internal constant numberOfTokensToSwapToLiquidity = TOTAL_SUPPLY / 100; // 0.1% of the total supply

    // --------------------- Fees Settings ------------------- //

    /**
     * @dev To add/edit/remove fees scroll down to the `addFees` function below
     */

    address payable internal charityAddress = payable(0x9D362e31246F5A7D6E98fBFB8C055854287893D4);
    address payable internal marketingAddress = payable(0x8aD4cB6f5A6Fbd8d3230A592F5afa0CC9E3fA631);

    /**
     * @dev You can change the value of the burn address to pretty much anything
     * that's (clearly) a non-random address, i.e. for which the probability of 
     * someone having the private key is (virtually) 0. For example, 0x00.....1, 
     * 0x111...111, 0x12345.....12345, etc.
     *
     * NOTE: This does NOT need to be the zero address, adress(0) = 0x000...000;
     *
     * Trasfering tokens to the burn address is good for optics/marketing. Nevertheless
     * if the burn address is excluded from rewards, sending tokens
     * to the burn address actually improves redistribution to holders (as they will
     * have a larger % of tokens in non-excluded accounts)
     *
     * p.s. the address below is the speed of light in vacuum in m/s (expressed in decimals),
     * the hex value is 0x0000000000000000000000000000000011dE784A; :)
     *
     * Here are the values of some other fundamental constants to use:
     * 0x0000000000000000000000000000000602214076 (Avogardo constant)
     * 0x0000000000000000000000000000000001380649 (Boltzmann constant)
     * 0x2718281828459045235360287471352662497757 (e)
     * 0x0000000000000000000000000000001602176634 (elementary charge)
     * 0x0000000000000000000000000200231930436256 (electron g-factor)
     * 0x0000000000000000000000000000091093837015 (electron mass)
     * 0x0000000000000000000000000000137035999084 (fine structure constant)
     * 0x0577215664901532860606512090082402431042 (Euler-Mascheroni constant)
     * 0x1618033988749894848204586834365638117720 (golden ratio)
     * 0x0000000000000000000000000000009192631770 (hyperfine transition fq)
     * 0x0000000000000000000000000000010011659208 (muom g-2)
     * 0x3141592653589793238462643383279502884197 (pi)
     * 0x0000000000000000000000000000000662607015 (Planck's constant)
     * 0x0000000000000000000000000000001054571817 (reduced Planck's constant)
     * 0x1414213562373095048801688724209698078569 (sqrt(2))
     */
    address internal immutable burnAddress = 0x0000000000000000000000000000000299792458;


    enum FeeType { Antiwhale, Burn, Liquidity, Rfi, External, ExternalToETH }
    struct Fee {
        FeeType name;
        uint256 value;
        address recipient;
        uint256 total;
    }

    Fee[] internal fees;
    uint256 internal sumOfFees;

    constructor() {
        _addFees();
    }

    function _addFee(FeeType name, uint256 value, address recipient) private {
        fees.push( Fee(name, value, recipient, 0 ) );
        sumOfFees += value;
    }

    function _addFees() private {

        /**
         * The RFI recipient is ignored but we need to give a valid address value
         *
         * CAUTION: If you don't want to use RFI this implementation isn't really for you!
         *      There are much more efficient and cleaner token contracts without RFI 
         *      so you should use one of those
         *
         * The value of fees is given in part per 1000 (based on the value of FEES_DIVISOR),
         * e.g. for 5% use 50, for 3.5% use 35, etc. 
         */ 
        _addFee(FeeType.Rfi, 20, address(this) ); 

        _addFee(FeeType.Burn, 5, burnAddress );
        _addFee(FeeType.Liquidity, 30, address(this) );
        _addFee(FeeType.External, 20, charityAddress );
        _addFee(FeeType.External, 30, marketingAddress );

        
    }

    function _getFeesCount() internal view returns (uint256){ return fees.length; }

    function _getFeeStruct(uint256 index) private view returns(Fee storage){
        require( index >= 0 && index < fees.length, "FeesSettings._getFeeStruct: Fee index out of bounds");
        return fees[index];
    }
    function _getFee(uint256 index) internal view returns (FeeType, uint256, address, uint256){
        Fee memory fee = _getFeeStruct(index);
        return ( fee.name, fee.value, fee.recipient, fee.total );
    }
    function _addFeeCollectedAmount(uint256 index, uint256 amount) internal {
        Fee storage fee = _getFeeStruct(index);
        fee.total = fee.total.add(amount);
    }

    // function getCollectedFeeTotal(uint256 index) external view returns (uint256){
    function getCollectedFeeTotal(uint256 index) internal view returns (uint256){
        Fee memory fee = _getFeeStruct(index);
        return fee.total;
    }
}

