pragma solidity ^0.5.12;

// import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./Ownable.sol";

contract KittyContract is IERC721, Ownable {

    string private tokenName;
    string private tokenSymbol;
    uint256 public constant CREATION_LIMIT_GEN0 = 10;
    bytes4 internal constant ERC721_RECEIVED = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));

    // A given constant that is calculated from ERC721 function headers (bitwise XOR product of them)
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    // A given constant that is caluclated from ERC165 "supportsInterface(bytes4)" function header
    // ERC165 is a standard to publish and detect what interfaces a smart contract implements
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    event Birth(address owner, uint256 kittenId, uint256 mumId, uint256 dadId, uint256 genes);

    struct Kitty {
        uint256 genes;
        uint64 birthTime;
        uint32 mumId;
        uint32 dadId;
        uint16 generation;
    }

    mapping(uint256 => address) public owners;
    mapping(address => uint256) balances;
    mapping (uint256 => address) public tokenApprovals;

    // MYADDR => OPERATORADDR => TRUE/FALSE
    // operatorApprovals[MYADDR][OPERATORADDR] = false;
    mapping (address => mapping (address => bool)) private operatorApprovals;

    uint256 public gen0Counter;

    Kitty[] kitties;

    constructor(string memory _name, string memory _symbol) public {
        tokenName = _name;
        tokenSymbol = _symbol;
    }

    // ERC165
    function supportsInterface(bytes4 _interfaceId) pure external returns (bool) {
        return (_interfaceId ==  _INTERFACE_ID_ERC721 || _interfaceId == _INTERFACE_ID_ERC165 );
    }

    function createKittyGen0(uint256 genes) public onlyOwner returns(uint256) {
        require(gen0Counter < CREATION_LIMIT_GEN0);
        gen0Counter++;
        return _createKitty(0, 0, 0, genes, msg.sender);
    }

    function _createKitty(
        uint256 mumId,
        uint256 dadId,
        uint256 generation,
        uint256 genes,
        address owner
    ) private returns (uint256) {
        Kitty memory kitty = Kitty({
            genes: genes,
            birthTime: uint64(now),
            mumId: uint32(mumId),
            dadId: uint32(dadId),
            generation: uint16(generation)
        });
        uint256 newKittenId = kitties.push(kitty) - 1;
        emit Birth(owner, newKittenId, mumId, dadId, genes);
        _transfer(address(0), owner, newKittenId);
        return newKittenId;
    }

    function breed(uint256 _dadId, uint256 _mumId) public returns (uint256) {
        // Check ownership
        require(_owns(msg.sender, _dadId));
        require(_owns(msg.sender, _mumId));
        // Parent DNA and Generation
        (uint256 dadDna,,,,uint256 dadGeneration,) = getKitty(_dadId);
        (uint256 mumDna,,,,uint256 mumGeneration,) = getKitty(_mumId);
        // DNA
        uint256 newDna = _mixDna(dadDna, mumDna);
        // Figure out the generation
        uint kidGeneration = 0;
        if(dadGeneration > mumGeneration) {
            kidGeneration = dadGeneration + 1;
        }
        else {
            kidGeneration = mumGeneration + 1;
        }

        // Create a new cat with the new properties, give it to msg.sender
        _createKitty(_mumId, _dadId, kidGeneration, newDna, msg.sender);
        
    }

    function _mixDna(uint256 _dadDna, uint256 _mumDna) internal view returns (uint256) {
        // uint256 firstHalf = _dadDna / 100000000;
        // uint256 secondHalf = _mumDna % 100000000;

        // uint256 newDna = (firstHalf * 100000000) + secondHalf;
        // return newDna;

        // Advanced
        uint256[8] memory geneArray;
        uint8 random = uint8(now % 255); // binary between 00000000-11111111

        uint256 i = 1;
        uint256 index = 7;
        for (i = 1; i < 128; i=i*2) {
            // i: 1, 2, 4, 8, 16, 32, 64, 128 - powers of 2

            if(random & i != 0) {
                geneArray[index] = uint8(_mumDna % 100);
            }
            else {
                geneArray[index] = uint8(_dadDna & 100);
            }

            // Cut off the last 2 digits (the gene that we just processed)
            _mumDna = _mumDna / 100;
            _dadDna = _dadDna / 100;

            index = index - 1;
        }

        uint256 newGene;
        for(i = 0; i < 8; i++) {
            newGene = newGene + geneArray[i];
            if(i != 7) {
                newGene = newGene * 100;
            }
        }

        return newGene;
    }

    function getKitty(uint256 tokenId) public view returns (
        uint256 genes,
        uint256 birthTime,
        uint256 mumId,
        uint256 dadId,
        uint256 generation,
        address owner
    ) {
        Kitty storage kitty = kitties[tokenId];

        genes = kitty.genes;
        birthTime = uint256(kitty.birthTime);
        mumId = uint256(kitty.mumId);
        dadId = uint256(kitty.dadId);
        generation = uint256(kitty.generation);
        owner = owners[tokenId];
    }

    function balanceOf(address owner) external view returns (uint256 balance) {
        return balances[owner];
    }

    function totalSupply() external view returns (uint256 total) {
        return kitties.length;
    }

    function name() external view returns (string memory) {
        return tokenName;
    }

    function symbol() external view returns (string memory) {
        return tokenSymbol;
    }

    function _ownerOf(uint256 tokenId) internal view returns (address owner) {
        require(owners[tokenId] != address(0));
        return owners[tokenId];
    }

    function ownerOf(uint256 tokenId) external view returns (address owner) {
        return _ownerOf(tokenId);
    }


    function transfer(address to, uint256 tokenId) external {
        require(to != address(0));
        require(to != address(this));
        require(_owns(msg.sender, tokenId));
        
        _transfer(msg.sender, to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        balances[to]++;
        owners[tokenId] = to;

        if(from != address(0)) {
            balances[from]--;
            delete tokenApprovals[tokenId];
        }
        emit Transfer(from, to, tokenId);
    }

    function _owns(address claimant, uint256 tokenId) internal view returns(bool) {
        return owners[tokenId] == claimant;
    }

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external {
         require(_ownerOf(_tokenId) == msg.sender || operatorApprovals[_ownerOf(_tokenId)][msg.sender] == true );
        tokenApprovals[_tokenId] = _approved;
        emit Approval(msg.sender, _approved, _tokenId);
    }

    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external {
        require(_operator != msg.sender);
        operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address) {
        require(_tokenId < kitties.length);
        return tokenApprovals[_tokenId];
    }

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return operatorApprovals[_owner][_operator];
    }

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
         require(
             _ownerOf(_tokenId) == msg.sender || 
            // _isApprovedForAll
            operatorApprovals[_ownerOf(_tokenId)][msg.sender] == true ||  
            tokenApprovals[_tokenId] == msg.sender    
        );
        require(_ownerOf(_tokenId) == _from);
        require(_to != address(0));
        require(_tokenId < kitties.length);
        _transfer(_from, _to, _tokenId);
    }

    function _safeTransfer(address _from, address _to, uint256 _tokenId, bytes memory _data) internal {
        _transfer(_from, _to, _tokenId);
        require(_checkERC721Support(_from, _to, _tokenId, _data));
    }

    function _checkERC721Support(address _from, address _to, uint256 _tokenId, bytes memory _data) internal returns(bool) {
        if(!_isContract(_to)) {
            return true;
        }

        bytes4 returnData = IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
        return returnData == ERC721_RECEIVED;
    }

    function _isContract(address to) view internal returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(to)
        }
        return size > 0;
    }

     /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external {
        _safeTransferFrom(_from, _to, _tokenId, data);
    }
    
    function _safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) internal {
        require(
             _ownerOf(_tokenId) == msg.sender || 
            // _isApprovedForAll
            operatorApprovals[_ownerOf(_tokenId)][msg.sender] == true ||  
            tokenApprovals[_tokenId] == msg.sender    
        );
        require(_ownerOf(_tokenId) == _from);
        require(_to != address(0));
        require(_tokenId < kitties.length);

        _safeTransfer(_from, _to, _tokenId, data);
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        _safeTransferFrom(_from, _to, _tokenId, "");
    }
}