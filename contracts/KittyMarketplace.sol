pragma solidity ^0.5.12;

import "./KittyContract.sol";
import "./IKittyMarketplace.sol";
import "./Ownable.sol";

contract KittyMarketplace is IKittyMarketPlace, Ownable {

    KittyContract private _kittyContract;

    struct Offer {
        address payable seller;
        uint256 price;
        uint256 index;
        uint256 tokenId;
        bool active;
    }

    Offer[] offers;

    mapping(uint256 => Offer) tokenIdToOffer;

    constructor(address _kittyContractAddress) public {
        _setKittyContract(_kittyContractAddress);
    }

    /**
    * Set the current KittyContract address and initialize the instance of Kittycontract.
    * Requirement: Only the contract owner can call.
     */
    function setKittyContract(address _kittyContractAddress) external onlyOwner {
        _setKittyContract(_kittyContractAddress);
    }
    function _setKittyContract(address _kittyContractAddress) internal {
        _kittyContract = KittyContract(_kittyContractAddress);
    }

    /**
    * Get the details about a offer for _tokenId. Throws an error if there is no active offer for _tokenId.
     */
    function getOffer(uint256 _tokenId) external view returns ( address seller, uint256 price, uint256 index, uint256 tokenId, bool active) {
        require(tokenIdToOffer[_tokenId].seller == address(0));
        Offer storage offer = tokenIdToOffer[_tokenId];
        seller = offer.seller;
        price = offer.price;
        index = offer.index;
        tokenId = offer.tokenId;
        active = offer.active;
    }

    /**
    * Get all tokenId's that are currently for sale. Returns an empty arror if none exist.
     */
    function getAllTokenOnSale() external view  returns(uint256[] memory listOfOffers) {
        if(offers.length == 0) {
            return new uint256[](0);
        } else {
            
            // ERROR: if total offers is >= 1 but none are active
            // result will be initialized to 1 and will be [0]
            // we need an empty array
            // we could create an a cat with id 0
            // or we need to have all offer indexes start from 1 [0] wouldn't be a valid offer
            uint256[] memory result = new uint256[](offers.length);
            uint256 resultLength = 0;
            for (uint256 i = 0; i < offers.length; i++) {
                if(offers[i].active == true) {
                    result[resultLength] = offers[i].tokenId;
                    resultLength++;
                }
            }

            if(resultLength <= 0) {
                return new uint256[](0);
            }
            return result;
        }
    }

    /**
    * Creates a new offer for _tokenId for the price _price.
    * Emits the MarketTransaction event with txType "Create offer"
    * Requirement: Only the owner of _tokenId can create an offer.
    * Requirement: There can only be one active offer for a token at a time.
    * Requirement: Marketplace contract (this) needs to be an approved operator when the offer is created.
     */
    function setOffer(uint256 _price, uint256 _tokenId) external {
        require(_kittyContract.ownerOf(_tokenId) == msg.sender);
        require(_kittyContract.isApprovedForAll(msg.sender, address(this)) == true);

        Offer memory newOffer = Offer(msg.sender, _price, offers.length, _tokenId, true);
        offers.push(newOffer);

        Offer storage lastOffer = tokenIdToOffer[_tokenId];
        lastOffer.active = false;

        tokenIdToOffer[_tokenId] = newOffer;
        emit MarketTransaction("Create offer", msg.sender, _tokenId);
    }

    /**
    * Removes an existing offer.
    * Emits the MarketTransaction event with txType "Remove offer"
    * Requirement: Only the seller of _tokenId can remove an offer.
     */
    function removeOffer(uint256 _tokenId) external {
        require(tokenIdToOffer[_tokenId].seller == msg.sender);
        offers[tokenIdToOffer[_tokenId].index].active = false;
        delete tokenIdToOffer[_tokenId];

        emit MarketTransaction("Remove offer", msg.sender, _tokenId);
    }

    /**
    * Executes the purchase of _tokenId.
    * Sends the funds to the seller and transfers the token using transferFrom in Kittycontract.
    * Emits the MarketTransaction event with txType "Buy".
    * Requirement: The msg.value needs to equal the price of _tokenId
    * Requirement: There must be an active offer for _tokenId
     */
    function buyKitty(uint256 _tokenId) external payable {
        require(tokenIdToOffer[_tokenId].active == true);
        require(tokenIdToOffer[_tokenId].seller != address(0));
        require(msg.value == tokenIdToOffer[_tokenId].price);

        // For some reason the offers[tokenIdToOffer[_tokenId.index]] and tokenIdToOffer[_tokenId]
        // don't point to the same Struct instance.
        delete tokenIdToOffer[_tokenId];
        offers[tokenIdToOffer[_tokenId].index].active = false;
        
        if(tokenIdToOffer[_tokenId].price > 0) {
            tokenIdToOffer[_tokenId].seller.transfer(msg.value);
        }
        _kittyContract.transferFrom(tokenIdToOffer[_tokenId].seller, msg.sender, _tokenId);

        emit MarketTransaction("Buy", msg.sender, _tokenId);     
    }
}