pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IERC2266.sol";

contract ERC2266 is IERC2266 {
    using SafeMath for uint256;
    
    /*
        * mapping for `Swap` type, each swap object 
        * will be mapped with `bytes32` as key, and 
        * `Swap` object as value
    */
    mapping(bytes32 => Swap) public swap;
    
    /*
        * mapping for `InitiatorAsset`, each `InitiatorAsset`
        * object will be mapped with `bytes32` as key, and 
        * `InitiatorAsset` object as value
    */ 
    mapping(bytes32 => InitiatorAsset) public initiatorAsset;
    
    /*
        * mapping for `ParticipantAsset`, each `ParticipantAsset`
        * object will be mapped with `bytes32` as key, and 
        * `ParticipantAsset` object as value 
    */ 
    mapping(bytes32 => ParticipantAsset) public participantAsset;
    
    /*
        * mapping for `Premium`, each `Premium`
        * object will be mapped with `bytes32` as key, and 
        * `Premium` object as value
    */ 
    mapping(bytes32 => Premium) public premium;


    constructor() public {}

    modifier isInitiatorAssetEmptyState(bytes32 secretHash) {
        require(initiatorAsset[secretHash].state == AssetState.Empty);
        _;
    }

    modifier isParticipantAssetEmptyState(bytes32 secretHash) {
        require(participantAsset[secretHash].state == AssetState.Empty);
        _;
    }

    modifier isPremiumEmptyState(bytes32 secretHash) {
        require(premium[secretHash].state == AssetState.Empty);
        _;
    }

    modifier canSetup(bytes32 secretHash) {
        require(initiatorAsset[secretHash].state == AssetState.Empty);
        require(participantAsset[secretHash].state == AssetState.Empty);
        require(premium[secretHash].state == AssetState.Empty);
        _;
    }

    modifier canInitiate(bytes32 secretHash) {
        require(swap[secretHash].initiator == msg.sender);
        require(initiatorAsset[secretHash].state == AssetState.Empty);
        require(ERC20(swap[secretHash].tokenA).balanceOf(msg.sender) >= initiatorAsset[secretHash].amount);
        _;
    }

    modifier canFillPremium(bytes32 secretHash) {
        require(swap[secretHash].initiator == msg.sender);
        require(premium[secretHash].state == AssetState.Empty);
        require(ERC20(swap[secretHash].tokenB).balanceOf(msg.sender) >= premium[secretHash].amount);
        _;
    }

    modifier canParticipate(bytes32 secretHash) {
        require(swap[secretHash].participant == msg.sender);
        require(participantAsset[secretHash].state == AssetState.Empty);
        require(premium[secretHash].state == AssetState.Filled);
        require(ERC20(swap[secretHash].tokenB).balanceOf(msg.sender) >= participantAsset[secretHash].amount);
        _;
    }

    modifier checkRefundTimestampOverflow(uint256 refundTime) {
        uint256 refundTimestamp = block.timestamp + refundTime;
        require(refundTimestamp > block.timestamp, "calc refundTimestamp overflow");
        require(refundTimestamp > refundTime, "calc refundTimestamp overflow");
        _;
    }

    modifier isAssetRedeemable(bytes32 secretHash, bytes32 secret) {
        if (swap[secretHash].initiator == msg.sender) {
            require(initiatorAsset[secretHash].state == AssetState.Filled);
            require(block.timestamp <= initiatorAsset[secretHash].refundTimestamp);
        } else {
            require(swap[secretHash].participant == msg.sender);
            require(participantAsset[secretHash].state == AssetState.Filled);
            require(block.timestamp <= participantAsset[secretHash].refundTimestamp);
        }
        require(sha256(abi.encodePacked(secret)) == secretHash);
        _;
    }

    modifier isAssetRefundable(bytes32 secretHash) {
        if (swap[secretHash].initiator == msg.sender) {
            require(initiatorAsset[secretHash].state == AssetState.Filled);
            require(block.timestamp > initiatorAsset[secretHash].refundTimestamp);
        } else {
            require(swap[secretHash].participant == msg.sender);
            require(participantAsset[secretHash].state == AssetState.Filled);
            require(block.timestamp > participantAsset[secretHash].refundTimestamp);
        }
        _;
    }

    modifier isPremiumFilledState(bytes32 secretHash) {
        require(premium[secretHash].state == AssetState.Filled);
        _;
    }

    // Premium is redeemable for Bob if Bob participates and redeem
    // before premium's timelock expires
    modifier isPremiumRedeemable(bytes32 secretHash) {
        // the participant invokes this method to redeem the premium
        require(swap[secretHash].participant == msg.sender);
        // the premium should be deposited
        require(premium[secretHash].state == AssetState.Filled);
        // if Bob participates, which means participantAsset will be: Filled -> (Redeemed/Refunded)
        require(participantAsset[secretHash].state == AssetState.Refunded || participantAsset[secretHash].state == AssetState.Redeemed);
        // the premium timelock should not be expired
        require(block.timestamp <= premium[secretHash].refundTimestamp);
        _;
    }

    // Premium is refundable for Alice only when Alice initiates
    // but Bob does not participate after premium's timelock expires
    modifier isPremiumRefundable(bytes32 secretHash) {
        // the initiator invokes this method to refund the premium
        require(swap[secretHash].initiator == msg.sender);
        // the premium should be deposited
        require(premium[secretHash].state == AssetState.Filled);
        // asset2 should be empty
        // which means Bob does not participate
        require(participantAsset[secretHash].state == AssetState.Empty);
        require(block.timestamp > premium[secretHash].refundTimestamp);
        _;
    }

    function setup(bytes32 secretHash,
                    address payable initiator,
                    address tokenA,
                    address tokenB,
                    uint256 initiatorAssetAmount,
                    address payable participant,
                    uint256 participantAssetAmount,
                    uint256 premiumAmount)
        public
        payable
        canSetup(secretHash)
    {
        swap[secretHash].secretHash = secretHash;
        swap[secretHash].initiator = initiator;
        swap[secretHash].participant = participant;
        swap[secretHash].tokenA = tokenA;
        swap[secretHash].tokenB = tokenB;
        initiatorAsset[secretHash].amount = initiatorAssetAmount;
        initiatorAsset[secretHash].state = AssetState.Empty;
        participantAsset[secretHash].amount = participantAssetAmount;
        participantAsset[secretHash].state = AssetState.Empty;
        premium[secretHash].amount = premiumAmount;
        premium[secretHash].state = AssetState.Empty;
        
        emit SetUp(
            secretHash,
            initiator,
            participant,
            tokenA,
            tokenB,
            initiatorAssetAmount,
            participantAssetAmount,
            premiumAmount
        );
    }

    // Initiator needs to pay for the initiatorAsset(tokenA) with initiatorAssetAmount
    // Initiator will also need to call tokenA.approve(this_contract_address, initiatorAssetAmount) in advance
    function initiate(bytes32 secretHash, uint256 assetRefundTime)
        public
        payable
        canInitiate(secretHash)
        checkRefundTimestampOverflow(assetRefundTime)
    {
        ERC20(swap[secretHash].tokenA).transferFrom(swap[secretHash].initiator, address(this), initiatorAsset[secretHash].amount);
        initiatorAsset[secretHash].state = AssetState.Filled;
        initiatorAsset[secretHash].refundTimestamp = block.timestamp + assetRefundTime;
        
        emit Initiated(
            block.timestamp,
            secretHash,
            msg.sender,
            swap[secretHash].participant,
            swap[secretHash].tokenA,
            initiatorAsset[secretHash].amount,
            initiatorAsset[secretHash].refundTimestamp
        );
    }

    // Initiator needs to pay for the premium(tokenB) with premiumAmount
    // Initiator will also need to call tokenB.approve(this_contract_address, premiumAmount) in advance
    function fillPremium(bytes32 secretHash, uint256 premiumRefundTime)
        public
        payable
        canFillPremium(secretHash)
        checkRefundTimestampOverflow(premiumRefundTime)
    {   
        ERC20(swap[secretHash].tokenB).transferFrom(swap[secretHash].initiator, address(this), premium[secretHash].amount);
        premium[secretHash].state = AssetState.Filled;
        premium[secretHash].refundTimestamp = block.timestamp + premiumRefundTime;
        
        emit PremiumFilled(
            block.timestamp,
            secretHash,
            msg.sender,
            swap[secretHash].participant,
            swap[secretHash].tokenB,
            premium[secretHash].amount,
            premium[secretHash].refundTimestamp
        );
    }

    // Participant needs to pay for the participantAsset(tokenB) with participantAssetAmount
    // Participant will also need to call tokenB.approve(this_contract_address, participantAssetAmount) in advance
    function participate(bytes32 secretHash, uint256 assetRefundTime)
        public
        payable
        canParticipate(secretHash)
        checkRefundTimestampOverflow(assetRefundTime)
    {
        ERC20(swap[secretHash].tokenB).transferFrom(swap[secretHash].participant, address(this), participantAsset[secretHash].amount);
        participantAsset[secretHash].state = AssetState.Filled;
        participantAsset[secretHash].refundTimestamp = block.timestamp + assetRefundTime;        
        
        emit Participated(
            block.timestamp,
            secretHash,
            swap[secretHash].initiator,
            msg.sender,
            swap[secretHash].tokenB,
            participantAsset[secretHash].amount,
            participantAsset[secretHash].refundTimestamp
        );
    }

    function redeemAsset(bytes32 secret, bytes32 secretHash)
        public
        isAssetRedeemable(secretHash, secret)
    {
        swap[secretHash].secret = secret;
        if (swap[secretHash].initiator == msg.sender) {
            ERC20(swap[secretHash].tokenB).transfer(msg.sender, participantAsset[secretHash].amount);
            participantAsset[secretHash].state = AssetState.Redeemed;

            emit ParticipantAssetRedeemed(
                block.timestamp,
                secretHash,
                secret,
                msg.sender,
                swap[secretHash].tokenB,
                participantAsset[secretHash].amount
            );
        } else {
            ERC20(swap[secretHash].tokenA).transfer(msg.sender, initiatorAsset[secretHash].amount);
            initiatorAsset[secretHash].state = AssetState.Redeemed;

            emit InitiatorAssetRedeemed(
                block.timestamp,
                secretHash,
                secret,
                msg.sender,
                swap[secretHash].tokenA,
                initiatorAsset[secretHash].amount
            );
        }
    }

    function refundAsset(bytes32 secretHash)
        public
        isPremiumFilledState(secretHash)
        isAssetRefundable(secretHash)
    {
        if (swap[secretHash].initiator == msg.sender) {
            ERC20(swap[secretHash].tokenA).transfer(msg.sender, initiatorAsset[secretHash].amount);
            initiatorAsset[secretHash].state = AssetState.Refunded;

            emit InitiatorAssetRefunded(
                block.timestamp,
                secretHash,
                msg.sender,
                swap[secretHash].tokenA,
                initiatorAsset[secretHash].amount
            );
        } else {
            ERC20(swap[secretHash].tokenB).transfer(msg.sender, participantAsset[secretHash].amount);
            participantAsset[secretHash].state = AssetState.Refunded;

            emit ParticipantAssetRefunded(
                block.timestamp,
                secretHash,
                msg.sender,
                swap[secretHash].tokenB,
                participantAsset[secretHash].amount
            );
        }
    }

    function redeemPremium(bytes32 secretHash)
        public
        isPremiumRedeemable(secretHash)
    {
        ERC20(swap[secretHash].tokenB).transfer(msg.sender, premium[secretHash].amount);
        premium[secretHash].state = AssetState.Redeemed;

        emit PremiumRefunded(
            block.timestamp,
            swap[secretHash].secretHash,
            msg.sender,
            swap[secretHash].tokenB,
            premium[secretHash].amount
        );
    }
  
    function refundPremium(bytes32 secretHash)
        public
        isPremiumRefundable(secretHash)
    {
        ERC20(swap[secretHash].tokenB).transfer(msg.sender, premium[secretHash].amount);
        premium[secretHash].state = AssetState.Refunded;

        emit PremiumRefunded(
            block.timestamp,
            swap[secretHash].secretHash,
            msg.sender,
            swap[secretHash].tokenB,
            premium[secretHash].amount
        );
    }
    
}