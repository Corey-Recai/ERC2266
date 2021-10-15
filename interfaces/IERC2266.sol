pragma solidity ^0.5.0;

/*
    * Interface of the ERC226 standard as defined in the EIP.
    * Outlined here: https://eips.ethereum.org/EIPS/eip-2266
*/

interface IERC2266 {
    
    /*
        * enum for `AssetState`, defiles the states
        * that the contract can be in
        * contract is initially at `Empty` state
        * once `setup` is called state is changed 
        * to `Filled`
    */ 
    enum AssetState { Empty, Filled, Redeemed, Refunded }
    
    /*
        * create a `Swap` type for the swap data
    */
    struct Swap {
        bytes32 secretHash;
        bytes32 secret;
        address payable initiator;
        address payable participant;
        address tokenA;
        address tokenB;
    }

    /*
        * create an `InitiatorAsset` type for the 
        * initiator asset
    */
    struct InitiatorAsset {
        uint256 amount;
        uint256 refundTimestamp;
        AssetState state;
    }
    
    /*
        * create an `ParticipantAsset` type for the 
        * participant asset
    */
    struct ParticipantAsset {
        uint256 amount;
        uint256 refundTimestamp;
        AssetState state;
    }

    /*
        * create an `Premium` type for the 
        * swap premium
    */
    struct Premium {
        uint256 amount;
        uint256 refundTimestamp;
        AssetState state;
    }

    
    /*
        * This function sets up the swap contract, 
        * including the both parties involved, 
        * the tokens to exchanged, participant asset amount,
        * and initiator premium amount
    */
    function setup(
        bytes32 secretHash, 
        address payable initiator, 
        address tokenA, address tokenB, 
        uint256 initiatorAssetAmount, 
        address payable participant, 
        uint256 participantAssetAmount, 
        uint256 premiumAmount
        ) external payable;
        
    /*
        * The initiator invokes this function to fill and lock 
        * the token party wants to sell and join the contract
    */
    function initiate(bytes32 secretHash, uint256 assetRefundTime) external payable;
    
    
    /*
        * The initiator invokes the `fillPremium` function 
        * to fill and lock the premium
    */
    function fillPremium(bytes32 secretHash, uint256 premiumRefundTime) external payable;
    
    
    /*
        * The participant invokes this function to fill and lock 
        * the token they want to sell and join the contract
    */
    function participate(bytes32 secretHash, uint256 assetRefundTime) external payable;
    
    
    /*
        * One of the parties invokes this function to get the token 
        * from the other party, by providing the preimage of 
        * the hash lock secret
    */
    function redeemAsset(bytes32 secret, bytes32 secretHash) external;
    
    
    /*
        * One of the parties invokes this function to get the token 
        * back after the timelock expires
    */
    function refundAsset(bytes32 secretHash) external;
    
    /*
        * The participant invokes this function to get the premium. 
        * This can be invoked only if the participant has already 
        * invoked participate and the participant’s token is 
        * redeemed or refunded.
    */
    function redeemPremium(bytes32 secretHash) external;
    
    
    /*
        * The initiator invokes this function to get the premium 
        * back after the timelock expires.
    */
    function refundPremium(bytes32 secretHash) external;
    
    
    /*
        * Set Up event
        * Indicates that one party has set up the contract 
        * using the `setup()` function 
    */
   event SetUp(
        bytes32 secretHash,
        address initiator,
        address participant,
        address tokenA,
        address tokenB,
        uint256 initiatorAssetAmount,
        uint256 participantAssetAmount,
        uint256 premiumAmount
    );
    
    
    /*
        * Initiated event
        * Indicates that one party, `initiator`, has filled 
        * and locked the token to be exhchanged using the
        * `initiate` function
    */
    event Initiated(
        uint256 initiateTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        address initiatorAssetToken,
        uint256 initiatorAssetAmount,
        uint256 initiatorAssetRefundTimestamp
    );
    
    
    /*
        * Participated event
        * Indicates that one party, `participant`, has filled 
        * and locked the token to be exhchanged using the
        * `participate` function
    */
     event Participated(
        uint256 participateTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        address participantAssetToken,
        uint256 participantAssetAmount,
        uint256 participantAssetRefundTimestamp
    );
    
    /*
        * Premium Filled event
        * Indicates that one party, `initiator`, has filled 
        * and locked the premium using the `fillPremium` function
    */
    event PremiumFilled(
        uint256 fillPremiumTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        address premiumToken,
        uint256 premiumAmount,
        uint256 premiumRefundTimestamp
    );
    
    
    /*
        * Initiator Asset Redeemed event
        * Indicates that one party, `initiator`, has redeemed
        * the asset before the timelock by providing the `secret`
    */
    event InitiatorAssetRedeemed(
        uint256 redeemTimestamp,
        bytes32 secretHash,
        bytes32 secret,
        address redeemer,
        address assetToken,
        uint256 amount
    );
    
    /*
        * Participant Asset Redeemed event
        * Indicates that one party, `participant`, has redeemed
        * the asset before the timelock by providing the `secret`
    */
    event ParticipantAssetRedeemed(
        uint256 redeemTimestamp,
        bytes32 secretHash,
        bytes32 secret,
        address redeemer,
        address assetToken,
        uint256 amount
    );

    /*
        * Initiator Asset Refunded event
        * Indicates that one party, `initiator`, has been refunded
        * the asset after the timelock expires
    */
    event InitiatorAssetRefunded(
        uint256 refundTimestamp,
        bytes32 secretHash,
        address refunder,
        address assetToken,
        uint256 amount
    );
    
    
    /*
        * Participant Asset Refunded event
        * Indicates that one party, `participant`, has been refunded
        * the asset after the timelock expires
    */
    event ParticipantAssetRefunded(
        uint256 refundTimestamp,
        bytes32 secretHash,
        address refunder,
        address assetToken,
        uint256 amount
    );
    
    
    /*
        * Premium Redeemed event
        * Indicates that the `premium` has been redeemed
        * by the participant. THis implies that the asset is either
        * redeemed by `initiator` if it can provide the preimage of 
        * `secretHash` before `asset` timelock expires; or refunded
        * by `participant` if `asset` timelock expires
    */
    event PremiumRedeemed(
        uint256 redeemTimestamp,
        bytes32 secretHash,
        address redeemer,
        address token,
        uint256 amount
    );


    /*
        * Premium Refunded event
        * Indicates that the `premium` has been refunded
        * back to the `initiator`, becuase the `participant`
        * doesn't participate at all by the time the `premium`
        * timelock expires
    */
    event PremiumRefunded(
        uint256 refundTimestamp,
        bytes32 secretHash,
        address refunder,
        address token,
        uint256 amount
    );
}